# VPS 运维纳管魔法师 / cross-border-ops-wizard

`cross-border-ops-wizard` 是一个面向团队跨境工具运维的 VPS 纳管 Skill。典型场景是同时购买腾讯云 Lighthouse 境外 VPS 和域名后，快速完成主机纳管、域名解析、证书配置、x-ui 管理界面部署、健康检查、团队交付和后续维护。

`cross-border-ops-wizard` is a VPS operations Skill for teams maintaining cross-border tooling. A typical use case starts after purchasing a Tencent Cloud Lighthouse overseas VPS and a domain, then proceeds through host onboarding, DNS, certificates, x-ui admin panel deployment, health checks, team handover, and ongoing maintenance.

它聚焦“买完能部署、部署后能验收、交付后能维护”的完整流程。仓库只保留方法、模板和检查脚本，不包含真实服务器凭据、后台地址或私有链接。

It focuses on the full path from "purchased" to "deployed, verified, handed over, and maintainable". This repository only contains methods, templates, and check scripts; it does not contain real server credentials, admin URLs, or private links.

## 适合场景 / Use Cases

- 新购腾讯云 Lighthouse 境外 VPS 后的标准化纳管。
- Standardize onboarding after purchasing a Tencent Cloud Lighthouse overseas VPS.
- 已购买域名，需要绑定到 VPS 并配置 HTTPS。
- Bind a purchased domain to the VPS and configure HTTPS.
- 一键化部署 x-ui 管理界面，方便团队使用和维护跨境工具。
- Deploy an x-ui management panel so the team can use and maintain cross-border tooling.
- DNS、证书、HTTPS 网关、面板入口和健康检查配置。
- Configure DNS, certificates, HTTPS gateway, panel entry, and health checks.
- 节点不可达、证书异常、端口不通、速度慢等问题排查。
- Troubleshoot unreachable nodes, certificate issues, closed ports, and slow paths.
- 为团队交接生成 runbook 和敏感信息清单。
- Generate a team handover runbook and sensitive-information checklist.
- 将跨境工具的部署、验收、交接和日常维护沉淀为可复用 SOP。
- Turn deployment, verification, handover, and maintenance into a reusable SOP.

## 核心能力 / Core Capabilities

- 腾讯云 Lighthouse VPS 与域名采购前规划清单。
- Pre-purchase planning checklist for Tencent Cloud Lighthouse VPS and domain.
- 目标主机身份确认和 SSH 纳管。
- Target host identity verification and SSH onboarding.
- DNS 与证书检查。
- DNS and certificate checks.
- x-ui 管理界面部署流程、面板入口和账号交接边界。
- x-ui admin-panel deployment flow, entry model, and account handover boundaries.
- 公开/私有端口边界设计。
- Public/private port boundary design.
- 服务状态、日志、网络连通性和团队可用性验收。
- Service, log, network, and team-availability verification.
- 本地 runbook 和敏感交付手册骨架生成。
- Local runbook and sensitive handover skeleton generation.
- 变更前确认和回滚意识。
- Confirmation and rollback discipline before changes.

## 目录 / Repository Layout

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

## 快速检查 / Quick Check

```bash
python3 scripts/validate_skill_package.py --zip
python3 scripts/render_node_materials.py --help
```

## Skill 安装 / Skill Installation

Skill 分发包位置：

The distributable Skill package is located at:

```text
skill/cross-border-ops-wizard/cross-border-ops-wizard.zip
```

安装到本地 Skill 目录：

Install it into the local Skill directory:

```bash
mkdir -p ~/.codex/skills
unzip -o skill/cross-border-ops-wizard/cross-border-ops-wizard.zip -d ~/.codex/skills/
```

## License

MIT
