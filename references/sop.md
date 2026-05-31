# VPS Operations Handover SOP

## 1. Planning

Collect before purchasing Tencent Cloud Lighthouse overseas VPS or before first operation:

- business purpose
- target Lighthouse region and fallback region
- expected users/devices
- cloud provider and account owner
- domain/subdomain naming and DNS provider
- whether x-ui will be deployed for team management
- administrator model
- handover scope
- existing nodes that must remain untouched

## 2. Target Intake

Record the target tuple:

```text
alias=
provider=
region=
instance_id=
public_ip=
os=
domain=
role=
xui_enabled=
```

Run read-only probes first:

```bash
dig +short <domain>
nc -G 4 -vz <ip> 22
ssh -o BatchMode=yes <alias> 'hostname; cat /etc/os-release | sed -n "1,4p"'
```

## 3. DNS And SSH

DNS:

```text
<subdomain>    A    <public_ip>
```

Verify:

```bash
dig @1.1.1.1 +short <domain>
dig @8.8.8.8 +short <domain>
dig +short <domain>
```

Use one SSH key per node. Do not reuse keys across unrelated nodes.

## 4. x-ui And Gateway Shape

Recommended public surface:

- SSH for operators.
- HTTP health check and certificate challenge.
- HTTPS gateway.
- x-ui management entry protected by a randomized path, strong credentials, and an explicit firewall policy.

Keep internal admin services bound to local interfaces or protected by cloud
firewall rules. Public gateway paths should be randomized and protected by
strong authentication when management access is required.

## 5. Firewall Boundary

Cloud firewall and system firewall must agree. Document:

- public ports
- private ports
- intended source ranges
- health check path
- x-ui panel exposure model
- rollback command

Never flush firewall rules casually on a production node.

## 6. Certificate

Use HTTP-01 or DNS-01 according to the domain provider and access constraints.
After issuance, verify certificate subject, issuer and expiry.

## 7. Handover

Produce:

- public runbook
- sensitive handover manual
- local verification log
- next-maintenance checklist
- x-ui administrator access notes when approved by the user

Keep credentials and private links out of public git repositories.
