# VPS Operations Wizard / cross-border-ops-wizard

[中文](README.md) | English

Current version: `0.4.0`

`cross-border-ops-wizard` manages the access-asset lifecycle for teams maintaining cross-border tooling. It covers freshly provisioned overseas VPS hosts, DNS, certificates, x-ui / 3x-ui, node delivery, and maintenance. It also covers newly purchased residential/static proxies from validation through AdsPower or RoxyBrowser global inventory, profile association, and in-browser exit verification. **Tencent Cloud Lighthouse ships as a VPS profile**; other clouds and proxy providers use the same asset model.

It focuses on the full path from "provisioned" to "deployed, verified, handed over, and maintainable", and works across **Claude Code, Codex, WorkBuddy, and OpenClaw**. This repository only contains methods, templates, and check scripts; it does not contain real server credentials, admin URLs, or private links.

## Use Cases

- Standardize onboarding for a freshly provisioned overseas VPS on any provider (Lighthouse as a built-in profile).
- Bind a purchased domain to the VPS and configure HTTPS (an IP-only path is supported when there is no domain).
- Deploy an x-ui / 3x-ui management panel so the team can use and maintain cross-border tooling.
- Configure DNS, certificates, HTTPS gateway, panel entry, and health checks.
- Troubleshoot unreachable nodes, certificate issues, closed ports, and slow/lossy paths.
- Triage VLESS/Reality EOF, Clash/Mihomo fake-ip, and client hot-reload persistence failures.
- Validate a purchased residential/static proxy, its observed exit, and multi-A gateway health.
- Add reusable proxies to AdsPower/RoxyBrowser, associate profiles, and verify the in-browser exit.
- Generate a team handover runbook and sensitive-information checklist.
- Turn deployment, verification, handover, and maintenance into a reusable SOP.

## Core Capabilities

- Provider-agnostic pre-purchase planning checklist for an overseas VPS and domain.
- Target host identity verification and SSH onboarding.
- DNS and certificate checks.
- x-ui admin-panel deployment flow, entry model, and account handover boundaries.
- One-click node engine `scripts/node-wizard.sh` (deploy/verify/panel-open/panel-close/links/rollback).
- Public/private port boundary design.
- Service, log, network, and team-availability verification.
- Local runbook and sensitive handover skeleton generation.
- Fingerprint-browser acceptance from global inventory through profile association and readback.
- Confirmation and rollback discipline before changes.

## Repository Layout

```text
.
├── README.md
├── README.en.md
├── LICENSE
├── CHANGELOG.md
├── VERSION
├── docs/
│   └── superpowers/          # design spec + implementation plan for the engine
├── references/
│   ├── documentation.md
│   ├── fingerprint-browser-egress.md
│   ├── sop.md
│   └── verification.md
├── scripts/
│   ├── install.sh
│   ├── node-wizard.sh        # one-click node engine entrypoint
│   ├── lib/                  # engine libraries (secrets/preflight/config/verify/deploy/panel/rollback…)
│   ├── render_node_materials.py
│   └── validate_skill_package.py
├── tests/                    # zero-dependency bash tests (tests/run.sh runs all)
└── skill/
    └── cross-border-ops-wizard/
        └── SKILL.md
```

## Quick Check

```bash
python3 scripts/validate_skill_package.py
python3 scripts/render_node_materials.py --help
```

## Skill Installation (multi-agent, one shot)

`scripts/install.sh` assembles a self-contained skill bundle from source and installs it
into whichever agent skills dirs exist on this machine (Claude Code `~/.claude/skills`,
Codex `~/.codex/skills`, WorkBuddy `~/.workbuddy/skills`, OpenClaw `~/.openclaw/skills`,
shared `~/.agents/skills`):

```bash
scripts/install.sh            # install into agent dirs that already exist
scripts/install.sh --all      # create + install for every known agent
scripts/install.sh --dry-run  # preview targets only
scripts/install.sh --dest ~/.some-agent/skills   # explicit dir
```

Each run repackages from `SKILL.md + references/ + scripts/`, so it never ships a stale zip.

## License

MIT
