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
- Reality SNI/dest and whether the target was validated from a real client path
- chained-exit architecture, client email, and outbound tag when present
- whether the persisted template and runtime config survived a force restart
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
- client persistence notes when Clash/Mihomo or mobile clients must be updated
- mode-0600 location of generated VLESS links or local sidecar config
- common troubleshooting
- next-stage suggestions

Set sensitive files to mode `600`.

## Final Response Checklist

When finishing a node, report:

- target IP/domain/alias
- whether existing nodes were left untouched
- DNS and certificate result
- x-ui panel and team access verification result
- Reality target/SNI verification result
- chained-exit end-to-end result after a force restart, when applicable
- fingerprint-browser in-profile exit result and global association readback
- public/private port exposure
- verification summary
- local docs created
- remaining risks or manual checks
