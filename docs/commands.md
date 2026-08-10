# Command-by-Command Build Log

This document records the commands used to build and validate the lab. Secret values are represented by placeholders.

## 1. Start the existing Wazuh and Windows virtual machines

```powershell
$vmrun = 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
$wazuh = 'C:\Workspace\VMs\WAZUH-SIEM01\WAZUH-SIEM01.vmx'
$client = 'C:\Workspace\VMs\WIN11-CLIENT\WIN11-CLIENT.vmx'

& $vmrun start $wazuh gui
& $vmrun start $client gui
& $vmrun list
```

Purpose: power on only the two machines required for the initial validation and confirm that VMware recognizes both as running.

## 2. Discover the guest IP addresses

```powershell
& $vmrun getGuestIPAddress $wazuh -wait
& $vmrun getGuestIPAddress $client -wait
```

Validated results:

- `WAZUH-SIEM01`: `192.168.75.20`
- `WIN11-CLIENT`: `192.168.75.132`

Purpose: prove that both guests are connected to the private `VMnet1` network.

## 3. Verify the Wazuh endpoint

Run on `WAZUH-SIEM01`:

```bash
sudo /var/ossec/bin/agent_control -i 001
```

Validated result:

```text
Agent ID: 001
Agent Name: WIN11-CLIENT
Status: Active
Operating system: Microsoft Windows 11 Enterprise Evaluation
Client version: Wazuh v4.14.7
```

Purpose: confirm that the Windows endpoint is enrolled, connected, and sending keep-alive messages.

## 4. Identify the Windows laboratory account from inventory

Create a read-only copy of the Wazuh endpoint inventory database:

```bash
sudo cp /var/ossec/queue/db/001.db /tmp/001-readonly.db
sudo chown "$USER:$USER" /tmp/001-readonly.db
```

Query the user inventory with Python:

```bash
python3 - <<'PY'
import sqlite3

db = sqlite3.connect('/tmp/001-readonly.db')
query = '''
SELECT user_name, user_full_name, user_home, user_type
FROM sys_users
ORDER BY user_name
'''

for row in db.execute(query):
    print(row)
PY
```

Validated local account: `SOC Analyst` with profile path `C:\Users\SOC Analyst`.

Purpose: identify the correct guest username without guessing accounts or modifying Windows.

## 5. Authenticate for guest administration

The next command will be executed only after the existing laboratory password is provided. The password is supplied at runtime and is never written to this repository.

```powershell
$credential = Get-Credential -UserName 'SOC Analyst' -Message 'Windows lab credentials'
```

Status: pending valid Windows laboratory credentials.

## 6. Planned Sysmon installation

The following commands will be run inside the Windows guest after authentication and after downloading Sysmon from Microsoft Sysinternals:

```powershell
Expand-Archive .\Sysmon.zip -DestinationPath C:\Tools\Sysmon -Force
C:\Tools\Sysmon\Sysmon64.exe -accepteula -i C:\Tools\Sysmon\sysmonconfig.xml
Get-Service Sysmon64
wevtutil gl Microsoft-Windows-Sysmon/Operational
```

Purpose: install enhanced endpoint telemetry and verify that the Sysmon service and event channel are active.

## 7. Planned Wazuh collection configuration

Add this local file block to the Windows Wazuh agent configuration:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

Then restart only the Wazuh agent service inside the VM:

```powershell
Restart-Service WazuhSvc
Get-Service WazuhSvc
```

This does not restart the Windows host or the Windows guest operating system.
