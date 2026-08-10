# Command-by-Command Build Log

This is the exact workflow used to build and validate the lab. Passwords are represented by placeholders and were supplied only at runtime.

## 1. Define the VMware paths

```powershell
$vmrun = 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
$wazuh = 'C:\Workspace\VMs\WAZUH-SIEM01\WAZUH-SIEM01.vmx'
$client = 'C:\Workspace\VMs\WIN11-CLIENT\WIN11-CLIENT.vmx'
$kali = 'C:\Workspace\VMs\KALI01\kali-linux-2026.2-vmware-amd64.vmwarevm\kali-linux-2026.2-vmware-amd64.vmx'
```

These variables avoid repeatedly typing long paths.

## 2. Start and identify the machines

```powershell
& $vmrun start $wazuh nogui
& $vmrun start $client nogui
& $vmrun start $kali nogui
& $vmrun list

& $vmrun getGuestIPAddress $wazuh -wait
& $vmrun getGuestIPAddress $client -wait
& $vmrun getGuestIPAddress $kali -wait
```

Validated addresses:

```text
WAZUH-SIEM01  192.168.75.20
WIN11-CLIENT  192.168.75.132
KALI01        192.168.75.129
```

## 3. Download Sysmon from Microsoft and verify its signature

```powershell
New-Item -ItemType Directory -Path '.\tools\Sysmon' -Force
Invoke-WebRequest `
  -Uri 'https://download.sysinternals.com/files/Sysmon.zip' `
  -OutFile '.\tools\Sysmon.zip'
Expand-Archive '.\tools\Sysmon.zip' '.\tools\Sysmon' -Force
Get-AuthenticodeSignature '.\tools\Sysmon\Sysmon64.exe'
```

Validated signer:

```text
Microsoft Windows Publisher / Microsoft Corporation
Status: Valid
```

This prevents installation of a modified or unsigned executable.

## 4. Stage the files in the Windows guest

```powershell
$guestUser = 'SOC Analyst'
$guestPassword = '<WINDOWS_LAB_PASSWORD>'

& $vmrun -T ws -gu $guestUser -gp $guestPassword `
  copyFileFromHostToGuest $client '.\tools\Sysmon.zip' 'C:\Users\Public\Sysmon.zip'

& $vmrun -T ws -gu $guestUser -gp $guestPassword `
  copyFileFromHostToGuest $client '.\config\sysmon-lab.xml' 'C:\Users\Public\sysmon-lab.xml'

& $vmrun -T ws -gu $guestUser -gp $guestPassword `
  copyFileFromHostToGuest $client `
  '.\scripts\install-sysmon-and-configure-wazuh.ps1' `
  'C:\Users\Public\install-sysmon-and-configure-wazuh.ps1'
```

The placeholder is intentional: the actual password is not stored in Git.

## 5. Install Sysmon and configure Wazuh collection

```powershell
& $vmrun -T ws -gu $guestUser -gp $guestPassword `
  runProgramInGuest $client `
  'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -NoProfile -ExecutionPolicy Bypass `
  -File 'C:\Users\Public\install-sysmon-and-configure-wazuh.ps1'
```

The script performs these actions:

```powershell
Get-AuthenticodeSignature C:\LabTools\Sysmon\Sysmon64.exe
C:\LabTools\Sysmon\Sysmon64.exe -accepteula -i C:\LabTools\Sysmon\sysmon-lab.xml
Restart-Service WazuhSvc
Get-Service Sysmon64, WazuhSvc
Get-WinEvent -ListLog 'Microsoft-Windows-Sysmon/Operational'
```

If Sysmon already exists, `-c` updates its configuration instead of reinstalling it. Only the Wazuh agent service is restarted; Windows is not restarted.

The following Wazuh event channels were added:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
<localfile>
  <location>Microsoft-Windows-PowerShell/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

## 6. Run the harmless Windows simulation

```powershell
& $vmrun -T ws -gu $guestUser -gp $guestPassword `
  copyFileFromHostToGuest $client `
  '.\scripts\run-safe-powershell-simulation.ps1' `
  'C:\Users\Public\run-safe-powershell-simulation.ps1'

& $vmrun -T ws -gu $guestUser -gp $guestPassword `
  runProgramInGuest $client `
  'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -NoProfile -ExecutionPolicy Bypass `
  -File 'C:\Users\Public\run-safe-powershell-simulation.ps1'
```

The simulation creates one marker file, resolves the internal server name, and tests TCP/443 against the Wazuh VM. It does not download or execute payloads.

## 7. Run limited reconnaissance from Kali

Inside `KALI01`:

```bash
nmap -sT -Pn -p 135,139,445,3389 192.168.75.132 \
  -oN /tmp/kali-nmap-scan.txt
```

Meaning of the options:

- `-sT`: standard TCP connect scan.
- `-Pn`: do not depend on ICMP ping discovery.
- `-p`: test only the four listed Windows ports.
- `-oN`: save readable evidence.

Result: the Windows host was up and all four ports were `filtered`.

## 8. Collect Windows evidence

```powershell
Get-WinEvent -FilterHashtable @{
  LogName = 'Microsoft-Windows-Sysmon/Operational'
  StartTime = (Get-Date).AddMinutes(-30)
} | Where-Object Id -in 1,3,11,12,13,14,22
```

Validated events:

```text
Event ID 1   powershell.exe process creation
Event ID 11  C:\Lab\wazuh-detection-test.txt creation
Event ID 3   internal connection to 192.168.75.20:443
```

Wazuh agent log validation:

```text
Analyzing event log: Microsoft-Windows-Sysmon/Operational
Analyzing event log: Microsoft-Windows-PowerShell/Operational
Connected to the server: 192.168.75.20:1514/tcp
Agent is now online
```

## 9. Update the Sysmon configuration

After removing an overly broad internal-network filter, apply the focused configuration again:

```powershell
C:\LabTools\Sysmon\Sysmon64.exe `
  -accepteula -c C:\LabTools\Sysmon\sysmon-lab.xml
```

This keeps the useful PowerShell, command-shell, file, registry, and DNS telemetry while reducing background noise.

## 10. Install and validate the custom Wazuh rule

The rule is stored in `config/wazuh-local-rules.xml`:

```xml
<rule id="100100" level="10">
  <if_sid>92029</if_sid>
  <field name="win.eventdata.image" type="pcre2">(?i)\\powershell\.exe$</field>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)run-safe-powershell-simulation\.ps1</field>
  <description>Authorized lab: PowerShell attack-to-detection simulation observed</description>
  <mitre><id>T1059.001</id></mitre>
</rule>
```

Install it on the Wazuh manager:

```bash
sudo install -o root -g wazuh -m 0640 \
  /tmp/wazuh-local-rules.xml \
  /var/ossec/etc/rules/attack_to_detection_lab.xml

sudo /var/ossec/bin/wazuh-analysisd -t
sudo systemctl restart wazuh-manager
systemctl is-active wazuh-manager
```

Validation result:

```text
Rule ID: 100100
Validation: Passed
Manager: active
Real matches: 1
Alert level: 10
Agent: WIN11-CLIENT
Sysmon Event ID: 1
```

Purpose: turn the endpoint telemetry into a reproducible, analyst-owned SIEM detection rather than relying only on generic rules.

## 11. Stop the lab when finished

Use guest shutdowns when convenient; do not force-stop a VM that is writing data:

```powershell
& $vmrun stop $kali soft
& $vmrun stop $client soft
& $vmrun stop $wazuh soft
```

This step is optional and was not used while the lab was being validated.
