# 跨境运维魔法师 / cross-border-ops-wizard

`cross-border-ops-wizard` 是一个面向跨境团队的轻量云主机运维 Skill。它帮助团队完成新节点规划、主机纳管、DNS、证书、网关、健康检查、排障和交付文档。

这个开源版本使用中性的运维表达，聚焦“可规划、可验收、可交接”的节点交付流程，不包含任何真实服务器凭据或私有链接。

## 适合场景

- 新购轻量云主机后的标准化纳管。
- DNS、证书、HTTPS 网关和健康检查配置。
- 节点不可达、证书异常、端口不通、速度慢等问题排查。
- 为团队交接生成 runbook 和敏感信息清单。
- 将跨境业务常见运维步骤沉淀为可复用 SOP。

## 核心能力

- 采购前规划清单。
- 目标主机身份确认。
- DNS 与证书检查。
- 公开/私有端口边界设计。
- 服务状态、日志、网络连通性验收。
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
