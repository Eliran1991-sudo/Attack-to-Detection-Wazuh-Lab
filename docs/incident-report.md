# SOC Incident Report: Authorized Lab Activity

## Executive summary

An authorized simulation was performed inside the private `192.168.75.0/24` VMware laboratory. Kali conducted limited reconnaissance against the Windows endpoint, and a harmless PowerShell script generated process, file, DNS, and network telemetry. Sysmon captured the activity and the Wazuh agent confirmed collection of the relevant event channels and an active encrypted connection to the manager.

## Scope

- Source: `KALI01` (`192.168.75.129`)
- Endpoint: `WIN11-CLIENT` (`192.168.75.132`)
- SIEM: `WAZUH-SIEM01` (`192.168.75.20`)
- Authorization: local owner-controlled laboratory
- External targets: none

## Timeline

| Time (UTC) | Activity | Evidence |
|---|---|---|
| 15:31:48 | PowerShell simulation started | Sysmon Event ID 1 |
| 15:31:49 | Marker file created | Sysmon Event ID 11 |
| 15:32:33 | TCP/443 connection test reached Wazuh | Sysmon Event ID 3 |
| 15:35:49 | Kali began limited Nmap scan | `evidence/kali-nmap-scan.txt` |
| 15:35:56 | Nmap scan completed | Four ports reported filtered |
| 11:27:55 server time | Custom SIEM detection matched | Wazuh rule 100100, level 10 |

## Findings

### 1. PowerShell execution captured

Sysmon recorded the full PowerShell command line, user, elevated integrity level, parent context, and SHA-256 process hash. This provides the core data needed for command-execution triage.

MITRE ATT&CK: `T1059.001 - PowerShell`.

### 2. File creation captured

Sysmon recorded the creation of `C:\Lab\wazuh-detection-test.txt` by `powershell.exe`.

MITRE ATT&CK context: file activity associated with command execution. The file itself was a harmless lab marker.

### 3. Reconnaissance was contained

Kali tested only TCP ports `135`, `139`, `445`, and `3389`. Windows was reachable, but all four ports were filtered. No exploitation, authentication attempt, persistence, or data access occurred.

MITRE ATT&CK: `T1046 - Network Service Discovery`.

### 4. Telemetry pipeline healthy

The Wazuh agent explicitly reported that it was analyzing the Sysmon and PowerShell channels, connected to `192.168.75.20:1514/tcp`, and came online. Both endpoint services remained running.

### 5. Custom Wazuh detection confirmed

Custom rule `100100` inherited the relevant built-in suspicious-PowerShell context, required the lab script name in the command line, and mapped the activity to `T1059.001`. A real event received from agent `001` matched the rule at level `10`.

## Severity and disposition

- Severity: Informational
- Classification: Authorized security validation
- Containment required: No
- Remediation required: No
- Recommendation: retain the focused Sysmon configuration and add dashboard visualizations for Event IDs 1, 3, 11, and 22.

## Analyst conclusion

The test achieved its goal without malware or unsafe exploitation. Endpoint telemetry was generated and captured, the Wazuh collection path was operational, custom rule `100100` generated a confirmed alert, and firewall filtering reduced the exposed Windows attack surface.
