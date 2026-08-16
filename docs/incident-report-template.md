# SOC Incident Report Template

Use this template only with evidence collected from an authorized environment. Replace every placeholder and remove sections that do not apply.

## Report metadata

| Field | Value |
| --- | --- |
| Report ID | `[IR-YYYY-NNN]` |
| Analyst | `[Name or lab role]` |
| Detection time | `[Timestamp and timezone]` |
| Investigation time | `[Timestamp and timezone]` |
| Environment | `[Authorized lab or organization]` |
| Status | `[Open, monitoring, or closed]` |

## Executive summary

`[Summarize what was detected, the affected system, the verified impact, and the final disposition.]`

## Scope and authorization

- Source system: `[Hostname and sanitized address]`
- Affected system: `[Hostname and sanitized address]`
- Detection source: `[SIEM rule, event ID, or alert]`
- Authorization: `[Why the activity was authorized or how scope was confirmed]`
- Exclusions: `[Systems or data outside the investigation]`

## Timeline

| Time and timezone | Activity | Evidence source |
| --- | --- | --- |
| `[Timestamp]` | `[Observed event]` | `[Log, alert, screenshot, or command output]` |

## Evidence

| Evidence item | Location | Validation notes |
| --- | --- | --- |
| `[Item]` | `[Repository path or sanitized reference]` | `[How authenticity and relevance were checked]` |

## Analysis

### Observed behavior

`[Describe only behavior supported by the evidence.]`

### Context and correlation

`[Correlate endpoint, identity, network, and SIEM data. Record alternative explanations.]`

### MITRE ATT&CK mapping

| Technique | Mapping rationale | Confidence |
| --- | --- | --- |
| `[Technique ID and name]` | `[Evidence-based reason]` | `[Low, medium, or high]` |

## Classification and impact

- Classification: `[True positive, benign positive, false positive, or undetermined]`
- Severity: `[Informational, low, medium, high, or critical]`
- Verified impact: `[Observed impact or none]`
- Escalation required: `[Yes or no, with reason]`

## Response actions

- Containment: `[Action taken or not required]`
- Eradication: `[Action taken or not required]`
- Recovery: `[Action taken or not required]`
- Monitoring: `[Follow-up queries, alerts, or time period]`

## Lessons learned

`[Record detection gaps, telemetry improvements, process improvements, and next steps.]`

## Privacy review

- [ ] No credentials, keys, or tokens are included.
- [ ] Personal and production information is removed or sanitized.
- [ ] Timestamps include their timezone.
- [ ] Claims are supported by published evidence.
- [ ] Screenshots were reviewed before publication.
