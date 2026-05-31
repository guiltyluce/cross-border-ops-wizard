# VPS 运维纳管魔法师 / cross-border-ops-wizard

中文 | [English](README.en.md)

`cross-border-ops-wizard` 是一个面向团队跨境工具运维的 VPS 纳管 Skill。典型场景是同时购买腾讯云 Lighthouse 境外 VPS 和域名后，快速完成主机纳管、域名解析、证书配置、x-ui 管理界面部署、健康检查、团队交付和后续维护。

它聚焦“买完能部署、部署后能验收、交付后能维护”的完整流程。仓库只保留方法、模板和检查脚本，不包含真实服务器凭据、后台地址或私有链接。

## 适合场景

- 新购腾讯云 Lighthouse 境外 VPS 后的标准化纳管。
- 已购买域名，需要绑定到 VPS 并配置 HTTPS。
- 一键化部署 x-ui 管理界面，方便团队使用和维护跨境工具。
- DNS、证书、HTTPS 网关、面板入口和健康检查配置。
- 节点不可达、证书异常、端口不通、速度慢等问题排查。
- 为团队交接生成 runbook 和敏感信息清单。
- 将跨境工具的部署、验收、交接和日常维护沉淀为可复用 SOP。

## 核心能力

- 腾讯云 Lighthouse VPS 与域名采购前规划清单。
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
│   ├── render_node_materials.py
│   └── validate_skill_package.py
└── skill/
    └── cross-border-ops-wizard/
        ├── SKILL.md
        └── cross-border-ops-wizard.zip
```

## 快速检查

```bash
python3 scripts/validate_skill_package.py --zip
python3 scripts/render_node_materials.py --help
```

## Skill 安装

Skill 分发包位置：

```text
skill/cross-border-ops-wizard/cross-border-ops-wizard.zip
```

安装到本地 Skill 目录：

```bash
mkdir -p ~/.codex/skills
unzip -o skill/cross-border-ops-wizard/cross-border-ops-wizard.zip -d ~/.codex/skills/
```

## License

MIT
