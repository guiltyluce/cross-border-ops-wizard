# Documentation Deliverables

Create two local files per node:

```text
<ALIAS>_RUNBOOK.md
<ALIAS>_HANDOVER_SENSITIVE.md
```

The runbook is shareable inside the operator team. The sensitive handover manual
contains credentials or private links only when the user explicitly approves the
destination.

## Runbook Contents

- provider, region, instance ID, IP, OS, SSH alias and role
- DNS record
- x-ui deployment status and management entry model
- public/private port model
- gateway and certificate layout
- verification commands and expected results
- service restart commands
- rollback notes
- change boundary: which nodes were left untouched

## Sensitive Handover Contents

- delivery status table
- administrator access notes
- x-ui panel URL/path and account owner, only when approved
- credential storage locations
- private links or tokens only when approved
- common troubleshooting
- next-stage suggestions

Set sensitive files to mode `600`.

## Final Response Checklist

When finishing a node, report:

- target IP/domain/alias
- whether existing nodes were left untouched
- DNS and certificate result
- x-ui panel and team access verification result
- public/private port exposure
- verification summary
- local docs created
- remaining risks or manual checks
