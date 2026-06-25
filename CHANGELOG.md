# Changelog

All notable changes to `cross-border-ops-wizard` are documented here.
Versioning follows [SemVer](https://semver.org/). Each release is also a git tag.

## [0.2.0] - 2026-06-25

### Changed
- Rewrote `SKILL.md` `description` to trigger-style ("Use when…"), dropped the
  workflow summary, and removed the Tencent-Lighthouse lock-in. The skill is now
  provider-agnostic, with Lighthouse kept as a built-in profile.
- Generalized `README.md` / `README.en.md` to "any overseas VPS" and multi-agent.

### Added
- `scripts/install.sh`: one-shot installer that assembles a self-contained bundle
  from source and installs into Claude Code, Codex, WorkBuddy, OpenClaw, and the
  shared `~/.agents` skills directories.
- `references/verification.md`: "Route / Packet-Loss Diagnosis" section for
  troubleshooting slow/lossy downloads (server-side vs path-side localization).
- `version` field in `SKILL.md` frontmatter.

### Removed
- Committed `cross-border-ops-wizard.zip` build artifact. It is now gitignored;
  regenerate on demand via `validate_skill_package.py --zip` or `install.sh`.

## [0.1.0] - initial

- Initial open-source release: SOP, verification, and documentation references,
  plus `render_node_materials.py` and `validate_skill_package.py`.
