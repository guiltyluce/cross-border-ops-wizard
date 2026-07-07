# One-Click Node Engine — Design Spec

- Target release: `cross-border-ops-wizard` v0.3.0
- Date: 2026-06-25
- Status: approved (design), pending implementation plan

## Goal

Turn a freshly provisioned overseas VPS into a working proxy node — xray VLESS
Reality plus an x-ui/3x-ui admin panel and team subscriptions — with a single
command that any agent (Claude Code, Codex, WorkBuddy, OpenClaw) can run over SSH.

"One command" means one invocation after the operator supplies `{alias, optional
domain}`, with at most a short, explicitly-listed manual cloud step (DNS record +
cloud firewall) that the engine detects and gates on.

## Non-Goals (YAGNI)

- No cloud / DNS API automation in v0.3.0 (left to a pluggable adapter in a later
  release).
- No multi-protocol / multi-inbound. One validated shape: VLESS Reality on 443.
- No always-on public admin panel.

## Architecture

A single idempotent bash engine, `scripts/node-wizard.sh`, run on the VPS as root.
Agents invoke it over SSH (`ssh <alias> 'bash -s' < scripts/node-wizard.sh <cmd> ...`).
Pure bash, no agent-specific dependencies, so it is identical across agents.

### Command surface

| Subcommand | Purpose |
| --- | --- |
| `deploy` | Full provisioning. Idempotent; re-run resumes. |
| `verify` | Run acceptance checks; print PASS/FAIL summary. |
| `panel-open` | Temporarily expose the admin gateway (cert + basic-auth + random path). |
| `panel-close` | Remove the public admin gateway exposure. |
| `links` | Print subscription / VLESS links from stored config. |
| `rollback` | Tear down what `deploy` created. |

### Flags (deploy)

- `--alias <name>` (required) — node identity, used for secret/file naming.
- `--domain <fqdn>` (optional) — enables the on-demand HTTPS panel gateway and a
  team-importable subscription URL. Omitted ⇒ IP-only proxy, panel via SSH tunnel only.
- `--profile <lighthouse|generic>` — cloud profile (default `generic`). `lighthouse`
  knows the cloud firewall is separate and the NIC MTU is often 8500.
- `--role <name>` — free-form label recorded in the runbook.

## Execution Model — Preflight Gate (semi-auto, pause-and-wait)

`deploy` begins with a **preflight gate**:

1. Detect whether the domain A record points at this host and whether the cloud
   firewall lets the required public ports through.
2. If **not ready**: print a precise checklist (which A record to add, which ports
   to open in the cloud console) and **exit non-zero**. The engine does not hang on
   an interactive prompt — unreliable for agents running over SSH.
3. Operator performs the manual cloud step, then the agent **re-runs `deploy`**.
   Because every phase is idempotent, the re-run resumes safely with no side effects.

## deploy Phases (all idempotent)

1. `preflight` — OS/arch detection, already-deployed detection, DNS + cloud-firewall readiness gate.
2. `system` — enable BBR + fq; install dependencies (nginx, firewalld, socat, sqlite, etc.).
3. `install` — install x-ui/3x-ui and xray-core.
4. `secrets` — generate per-node random values: Reality keypair, UUID, subscription ID,
   admin panel path, nginx basic-auth. Never reused across nodes.
5. `configure` — write xray VLESS Reality on `*:443`; bind the x-ui panel to `127.0.0.1:35179`;
   subscription backend on `127.0.0.1:2096`.
6. `cert` — when `--domain` is set, issue a Let's Encrypt HTTP-01 cert and stage it for the
   on-demand gateway. IP-only path skips this.
7. `firewall` — configure system firewalld: public `22/80/443`; gateway `35178` configured but
   only active while `panel-open`; private `35179/2096` bound locally.
8. `verify` — run acceptance checks (see below).
9. `emit` — write `/root/ops-secrets/<alias>.env` (mode 600); print panel entry, subscription
   link, VLESS link, and the verify summary. Private keys are never printed.

## Security Posture (panel exposure = option C)

- **Default**: x-ui panel bound to `127.0.0.1:35179`; zero public exposure. Management is via an
  SSH tunnel (`ssh -L`). The only public listener is the probe-resistant Reality inbound on 443.
- **On demand**: `panel-open` mounts `https://<domain>:35178/<random-path>/` protected by a valid
  certificate, nginx basic-auth, and x-ui login (three layers). `panel-close` removes it.
  `panel-open` applies the same preflight gate for port `35178`: if the cloud firewall blocks it,
  it prints the checklist and exits rather than opening a half-working gateway.
- Rationale: a domain is a convenience (HTTPS panel + importable subscription URL), not a security
  control. Attack surface is governed by open ports and admin exposure, not by the presence of a
  hostname. Keeping the panel off the public internet by default minimizes the real risk
  (x-ui panel scanning/brute-force).

## Secrets & Outputs

- Remote: `/root/ops-secrets/<alias>.env` (mode 600).
- Local: pulled to `~/.config/vps-ops/<alias>-*.env` (mode 600); runbook and sensitive handover
  generated via the existing `scripts/render_node_materials.py`.
- Screen output: panel entry, subscription link, VLESS link, PASS/FAIL — never private keys.

## Idempotency & Rollback

- Every `deploy` phase detects existing state and only fills gaps; re-running is safe and is the
  defined recovery path after the preflight gate.
- `rollback` removes services, configs, firewall rules, and staged certs created by `deploy`,
  leaving the host as found.

## Acceptance Criteria

- On a clean VPS with DNS + cloud firewall ready, a single `deploy` reaches `ALL PASS`:
  services active, Reality on 443, panel bound to localhost, BBR/fq on, (with domain) cert valid,
  subscription link resolves to `@<domain-or-ip>:443 security=reality flow=xtls-rprx-vision`.
- Re-running `deploy` on an already-provisioned node makes no changes and still reports `ALL PASS`.
- With DNS/firewall not ready, `deploy` prints an actionable checklist and exits non-zero without
  partial-configuring the node.
- `panel-open` then `panel-close` leaves no public admin listener.
- No private key or password is ever written to stdout.

## Cross-Agent Packaging

Ships as part of the skill bundle installed by `scripts/install.sh` into each agent's skills dir.
The engine is referenced from `SKILL.md` so agents discover and run it.
