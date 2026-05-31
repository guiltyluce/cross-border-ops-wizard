# VPS Operations Wizard / cross-border-ops-wizard

[中文](README.md) | English

`cross-border-ops-wizard` is a VPS operations Skill for teams maintaining cross-border tooling. A typical use case starts after purchasing a Tencent Cloud Lighthouse overseas VPS and a domain, then proceeds through host onboarding, DNS, certificates, x-ui admin panel deployment, health checks, team handover, and ongoing maintenance.

It focuses on the full path from "purchased" to "deployed, verified, handed over, and maintainable". This repository only contains methods, templates, and check scripts; it does not contain real server credentials, admin URLs, or private links.

## Use Cases

- Standardize onboarding after purchasing a Tencent Cloud Lighthouse overseas VPS.
- Bind a purchased domain to the VPS and configure HTTPS.
- Deploy an x-ui management panel so the team can use and maintain cross-border tooling.
- Configure DNS, certificates, HTTPS gateway, panel entry, and health checks.
- Troubleshoot unreachable nodes, certificate issues, closed ports, and slow paths.
- Generate a team handover runbook and sensitive-information checklist.
- Turn deployment, verification, handover, and maintenance into a reusable SOP.

## Core Capabilities

- Pre-purchase planning checklist for Tencent Cloud Lighthouse VPS and domain.
- Target host identity verification and SSH onboarding.
- DNS and certificate checks.
- x-ui admin-panel deployment flow, entry model, and account handover boundaries.
- Public/private port boundary design.
- Service, log, network, and team-availability verification.
- Local runbook and sensitive handover skeleton generation.
- Confirmation and rollback discipline before changes.

## Repository Layout

```text
.
├── README.md
├── LICENSE
├── references/
│   ├── documentation.md
│   ├── sop.md
│   └── verification.md
├── scripts/
│   ├── render_node_materials.py
│   └── validate_skill_package.py
└── skill/
    └── cross-border-ops-wizard/
        ├── SKILL.md
        └── cross-border-ops-wizard.zip
```

## Quick Check

```bash
python3 scripts/validate_skill_package.py --zip
python3 scripts/render_node_materials.py --help
```

## Skill Installation

The distributable Skill package is located at:

```text
skill/cross-border-ops-wizard/cross-border-ops-wizard.zip
```

Install it into the local Skill directory:

```bash
mkdir -p ~/.codex/skills
unzip -o skill/cross-border-ops-wizard/cross-border-ops-wizard.zip -d ~/.codex/skills/
```

## License

MIT
