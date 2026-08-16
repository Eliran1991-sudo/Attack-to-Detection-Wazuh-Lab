$ErrorActionPreference = 'Stop'

$package = 'C:\Users\Public\Sysmon.zip'
$configSource = 'C:\Users\Public\sysmon-lab.xml'
$installDirectory = 'C:\LabTools\Sysmon'
$configTarget = Join-Path $installDirectory 'sysmon-lab.xml'
$sysmonExecutable = Join-Path $installDirectory 'Sysmon64.exe'
$wazuhConfig = 'C:\Program Files (x86)\ossec-agent\ossec.conf'
$resultFile = 'C:\Users\Public\sysmon-validation-result.txt'

New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
Expand-Archive -LiteralPath $package -DestinationPath $installDirectory -Force
Copy-Item -LiteralPath $configSource -Destination $configTarget -Force

$signature = Get-AuthenticodeSignature -LiteralPath $sysmonExecutable
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') {
    throw "Sysmon signature validation failed: $($signature.Status)"
}

$existingService = Get-Service -Name 'Sysmon64' -ErrorAction SilentlyContinue
if ($existingService) {
    & $sysmonExecutable -accepteula -c $configTarget | Out-Null
    $sysmonAction = 'Configuration updated'
} else {
    & $sysmonExecutable -accepteula -i $configTarget | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Sysmon installation failed with exit code $LASTEXITCODE"
    }
    $sysmonAction = 'Installed'
}

if (-not (Test-Path -LiteralPath $wazuhConfig)) {
    throw "Wazuh agent configuration was not found at $wazuhConfig"
}

$wazuhText = [IO.File]::ReadAllText($wazuhConfig)
$changedWazuhConfig = $false

$channels = @(
    'Microsoft-Windows-Sysmon/Operational',
    'Microsoft-Windows-PowerShell/Operational'
)

foreach ($channel in $channels) {
    if ($wazuhText -notmatch [regex]::Escape($channel)) {
        $block = @"

  <localfile>
    <location>$channel</location>
    <log_format>eventchannel</log_format>
  </localfile>
"@
        $wazuhText = $wazuhText -replace '</ossec_config>\s*$', "$block`r`n</ossec_config>"
        $changedWazuhConfig = $true
    }
}

if ($changedWazuhConfig) {
    $backup = "$wazuhConfig.lab-backup"
    Copy-Item -LiteralPath $wazuhConfig -Destination $backup -Force
    [IO.File]::WriteAllText($wazuhConfig, $wazuhText, [Text.UTF8Encoding]::new($false))
}

Restart-Service -Name 'WazuhSvc' -Force

$sysmonService = Get-Service -Name 'Sysmon64'
$wazuhService = Get-Service -Name 'WazuhSvc'
$sysmonLog = Get-WinEvent -ListLog 'Microsoft-Windows-Sysmon/Operational'

@(
    "SYSMON_ACTION=$sysmonAction"
    "SYSMON_SIGNATURE=$($signature.Status)"
    "SYSMON_SIGNER=$($signature.SignerCertificate.Subject)"
    "SYSMON_SERVICE=$($sysmonService.Status)"
    "SYSMON_LOG_ENABLED=$($sysmonLog.IsEnabled)"
    "WAZUH_CONFIG_CHANGED=$changedWazuhConfig"
    "WAZUH_SERVICE=$($wazuhService.Status)"
) | Set-Content -LiteralPath $resultFile

