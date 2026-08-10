#!/usr/bin/env bash
set -euo pipefail

source_rule='/tmp/wazuh-local-rules.xml'
target_rule='/var/ossec/etc/rules/attack_to_detection_lab.xml'
result='/tmp/wazuh-rule-install-result.txt'
validation='/tmp/wazuh-rule-validation-root.txt'

if [[ ! -f "$source_rule" ]]; then
  echo "Rule source not found: $source_rule" >&2
  exit 1
fi

if [[ -f "$target_rule" ]]; then
  cp -a "$target_rule" "${target_rule}.codex-backup"
fi

install -o root -g wazuh -m 0640 "$source_rule" "$target_rule"

rm -f "$validation" "$result"

if ! /var/ossec/bin/wazuh-analysisd -t > "$validation" 2>&1; then
  if [[ -f "${target_rule}.codex-backup" ]]; then
    cp -a "${target_rule}.codex-backup" "$target_rule"
  else
    rm -f "$target_rule"
  fi
  cat "$validation" >&2
  exit 1
fi

systemctl restart wazuh-manager

{
  echo "RULE_FILE=$target_rule"
  echo "RULE_ID=100100"
  echo "VALIDATION=Passed"
  echo "MANAGER_STATUS=$(systemctl is-active wazuh-manager)"
} > "$result"

chown eliran:eliran "$result" "$validation"
