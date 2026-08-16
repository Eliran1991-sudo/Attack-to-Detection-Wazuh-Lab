#!/usr/bin/env bash
set -euo pipefail

output='/tmp/wazuh-server-evidence.txt'
alerts='/var/ossec/logs/alerts/alerts.json'

rm -f "$output" /tmp/wazuh-lab-alerts.jsonl

{
  echo "COLLECTED_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "MANAGER_STATUS=$(systemctl is-active wazuh-manager)"
  echo
  echo 'AGENTS'
  /var/ossec/bin/agent_control -lc
  echo
  echo 'ALERT_FILE'
  ls -l "$alerts"
  echo
  echo 'RECENT_MANAGER_LOG'
  tail -n 60 /var/ossec/logs/ossec.log
} > "$output"

grep -Ei 'sysmon|powershell|WIN11-CLIENT|agent 001' "$alerts" | tail -n 80 \
  > /tmp/wazuh-lab-alerts.jsonl || true

if [[ -n "${SUDO_USER:-}" ]]; then
  chown "$SUDO_USER":"$(id -gn "$SUDO_USER")" "$output" /tmp/wazuh-lab-alerts.jsonl
fi
