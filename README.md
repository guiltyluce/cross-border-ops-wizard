# VPS 运维纳管魔法师 / cross-border-ops-wizard

中文 | [English](README.en.md)

`cross-border-ops-wizard` 是一个面向团队跨境工具运维的 VPS 纳管 Skill。典型场景是拿到一台**新开的境外 VPS（任意云厂商）**后，快速完成主机纳管、域名解析、证书配置、x-ui / 3x-ui 管理界面部署、健康检查、团队交付和后续维护。**腾讯云 Lighthouse 作为内置 profile**，其他云按同一套流程纳管。

它聚焦“开机能部署、部署后能验收、交付后能维护”的完整流程，并适配 **Claude Code、Codex、WorkBuddy、OpenClaw** 等多种智能体。仓库只保留方法、模板和检查脚本，不包含真实服务器凭据、后台地址或私有链接。

## 适合场景

- 任意云厂商新开境外 VPS 后的标准化纳管（Lighthouse 为内置 profile）。
- 已购买域名，需要绑定到 VPS 并配置 HTTPS（无域名时可走纯 IP 简化路径）。
- 部署 x-ui / 3x-ui 管理界面，方便团队使用和维护跨境工具。
- DNS、证书、HTTPS 网关、面板入口和健康检查配置。
- 节点不可达、证书异常、端口不通、下载慢/丢包/线路差等问题排查。
- 为团队交接生成 runbook 和敏感信息清单。
- 将跨境工具的部署、验收、交接和日常维护沉淀为可复用 SOP。

## 核心能力

- 境外 VPS 与域名采购前规划清单（云厂商无关）。
- 目标主机身份确认和 SSH 纳管。
- DNS 与证书检查。
- x-ui 管理界面部署流程、面板入口和账号交接边界。
- 公开/私有端口边界设计。
- 服务状态、日志、网络连通性和团队可用性验收。
- 本地 runbook 和敏感交付手册骨架生成。
- 变更前确认和回滚意识。

## 目录

```text
.
├── README.md
├── LICENSE
├── references/
│   ├── documentation.md
│   ├── sop.md
│   └── verification.md
├── scripts/
│   ├── install.sh
│   ├── render_node_materials.py
│   └── validate_skill_package.py
└── skill/
    └── cross-border-ops-wizard/
        └── SKILL.md
```

## 快速检查

```bash
python3 scripts/validate_skill_package.py
python3 scripts/render_node_materials.py --help
```

## Skill 安装（多智能体一键）

`scripts/install.sh` 会从源码现场组装自包含 skill 包，并装入本机已存在的各智能体 skills 目录
（Claude Code `~/.claude/skills`、Codex `~/.codex/skills`、WorkBuddy `~/.workbuddy/skills`、
OpenClaw `~/.openclaw/skills`、共享 `~/.agents/skills`）：

```bash
scripts/install.sh            # 装入已存在的智能体目录
scripts/install.sh --all      # 为所有已知智能体创建并安装
scripts/install.sh --dry-run  # 只预览将安装到哪些目录
scripts/install.sh --dest ~/.some-agent/skills   # 指定任意目录
```

每次安装都从 `SKILL.md + references/ + scripts/` 现场打包，不依赖预置 zip，避免分发陈旧副本。

## License

MIT
