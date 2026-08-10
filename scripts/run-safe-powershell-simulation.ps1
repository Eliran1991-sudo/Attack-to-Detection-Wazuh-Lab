$ErrorActionPreference = 'Stop'

$labDirectory = 'C:\Lab'
$markerFile = Join-Path $labDirectory 'wazuh-detection-test.txt'

New-Item -ItemType Directory -Path $labDirectory -Force | Out-Null
Set-Content -LiteralPath $markerFile -Value @(
    'Authorized SOC lab simulation'
    "Timestamp: $([DateTime]::UtcNow.ToString('o'))"
    'Purpose: validate Sysmon and Wazuh telemetry'
)

Resolve-DnsName -Name 'wazuh-siem01' -ErrorAction SilentlyContinue | Out-Null
Test-NetConnection -ComputerName '192.168.75.20' -Port 443 -InformationLevel Quiet | Out-Null

@(
    'SIMULATION=Completed'
    "MARKER_FILE=$markerFile"
    "TIMESTAMP_UTC=$([DateTime]::UtcNow.ToString('o'))"
) | Set-Content -LiteralPath 'C:\Users\Public\codex-simulation-result.txt'
