$ErrorActionPreference = 'Stop'

$since = (Get-Date).AddMinutes(-30)
$output = 'C:\Users\Public\windows-soc-evidence.txt'

$sysmonEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-Sysmon/Operational'
    StartTime = $since
} -ErrorAction Stop | Where-Object {
    $_.Id -in 1, 3, 11, 12, 13, 14, 22
} | Select-Object -First 30

$service = Get-Service -Name 'Sysmon64', 'WazuhSvc' -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('COLLECTED_UTC=' + (Get-Date).ToUniversalTime().ToString('o'))
$lines.Add('HOST=' + $env:COMPUTERNAME)
$lines.Add('WINDOW_START=' + $since.ToString('o'))
$lines.Add('')
$lines.Add('SERVICES')
foreach ($item in $service) {
    $lines.Add(('{0}|{1}|{2}' -f $item.Name, $item.Status, $item.StartType))
}
$lines.Add('')
$lines.Add('SYSMON_EVENTS')
$lines.Add('COUNT=' + $sysmonEvents.Count)

foreach ($event in $sysmonEvents) {
    $message = ($event.Message -replace "`r?`n", ' | ')
    if ($message.Length -gt 900) {
        $message = $message.Substring(0, 900)
    }
    $lines.Add(('{0:o}|ID={1}|{2}' -f $event.TimeCreated, $event.Id, $message))
}

$agentLog = 'C:\Program Files (x86)\ossec-agent\ossec.log'
if (Test-Path -LiteralPath $agentLog) {
    $lines.Add('')
    $lines.Add('WAZUH_AGENT_LOG_TAIL')
    Get-Content -LiteralPath $agentLog -Tail 40 | ForEach-Object { $lines.Add($_) }
}

$lines | Set-Content -LiteralPath $output -Encoding UTF8

