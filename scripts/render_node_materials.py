#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render VPS operations handover material skeletons.")
    parser.add_argument("--alias", required=True)
    parser.add_argument("--domain", required=True)
    parser.add_argument("--public-ip", required=True)
    parser.add_argument("--provider", default="TBD")
    parser.add_argument("--region", default="TBD")
    parser.add_argument("--instance-id", default="TBD")
    parser.add_argument("--os", default="TBD")
    parser.add_argument("--role", default="cross-border tool node")
    parser.add_argument("--xui", action="store_true", help="Include x-ui deployment and handover sections.")
    parser.add_argument("--out-dir", default="output/node-materials")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    out_dir = Path(args.out_dir).expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)
    today = dt.date.today().isoformat()
    safe_alias = args.alias.replace("-", "_").upper()

    runbook = out_dir / f"{safe_alias}_RUNBOOK.md"
    sensitive = out_dir / f"{safe_alias}_HANDOVER_SENSITIVE.md"

    runbook.write_text(
        f"""# {args.alias} Runbook

Generated: {today}

## Target

- Alias: `{args.alias}`
- Provider: `{args.provider}`
- Region: `{args.region}`
- Instance ID: `{args.instance_id}`
- Public IP: `{args.public_ip}`
- Domain: `{args.domain}`
- OS: `{args.os}`
- Role: `{args.role}`
- x-ui enabled: `{str(args.xui).lower()}`

## DNS

```text
{args.domain}    A    {args.public_ip}
```

## Read-only Checks

```bash
dig +short {args.domain}
nc -G 4 -vz {args.public_ip} 22
ssh {args.alias} 'hostname; uptime; systemctl --failed --no-pager'
```

## HTTP/TLS Checks

```bash
curl --noproxy '*' -4sS -o /dev/null -w 'health=%{{http_code}} ip=%{{remote_ip}}\\n' http://{args.domain}/healthz
echo | openssl s_client -connect {args.domain}:443 -servername {args.domain} 2>/dev/null | openssl x509 -noout -issuer -subject -dates
```

## x-ui Checks

```bash
ssh {args.alias} 'systemctl status x-ui --no-pager || systemctl status xui --no-pager || true'
ssh {args.alias} 'journalctl -u x-ui -n 80 --no-pager || journalctl -u xui -n 80 --no-pager || true'
```

## Notes

- Record public/private port boundaries here.
- Record rollback commands here.
- Do not paste credentials into this public runbook.
""",
        encoding="utf-8",
    )

    sensitive.write_text(
        f"""# {args.alias} Sensitive Handover

Generated: {today}

This file may contain private operational details. Store it with mode `600`.

## Credential Locations

- Local secret file: TBD
- Remote secret directory: TBD

## Private Access Notes

- x-ui administrator URL/path: TBD
- Credential owner: TBD
- Rotation date: TBD

## Distribution Notes

- Who can receive access: TBD
- Revocation procedure: TBD
- Emergency contact: TBD
""",
        encoding="utf-8",
    )
    sensitive.chmod(0o600)

    print(runbook)
    print(sensitive)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
