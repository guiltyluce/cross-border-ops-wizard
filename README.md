# VPS 运维纳管魔法师 / cross-border-ops-wizard

中文 | [English](README.en.md)

当前版本：`0.5.0`

`cross-border-ops-wizard` 是一个面向团队跨境工具运维的访问资产纳管 Skill。它既覆盖新开境外 VPS 的主机、DNS、证书、x-ui / 3x-ui、节点交付与维护，也覆盖新购家宽/静态代理从验真、VPS 链式出站和手机 VLESS 节点，到 AdsPower、RoxyBrowser、BitBrowser 环境关联的完整流程。**腾讯云 Lighthouse 作为 VPS 内置 profile**，其他云和代理服务商按同一套资产模型纳管。

它聚焦“开机能部署、部署后能验收、交付后能维护”的完整流程，并适配 **Claude Code、Codex、WorkBuddy、OpenClaw** 等多种智能体。仓库只保留方法、模板和检查脚本，不包含真实服务器凭据、后台地址或私有链接。

## 适合场景

- 任意云厂商新开境外 VPS 后的标准化纳管（Lighthouse 为内置 profile）。
- 已购买域名，需要绑定到 VPS 并配置 HTTPS（无域名时可走纯 IP 简化路径）。
- 部署 x-ui / 3x-ui 管理界面，方便团队使用和维护跨境工具。
- DNS、证书、HTTPS 网关、面板入口和健康检查配置。
- 节点不可达、证书异常、端口不通、下载慢/丢包/线路差等问题排查。
- VLESS/Reality EOF、Clash/Mihomo fake-ip、客户端热加载未持久化等复合故障排查。
- 新购家宽/静态 IP 的代理连通性、真实出口和多 A 记录网关验收。
- 通过现有 VLESS/Reality VPS 为不同客户端增加独立代理出口。
- AdsPower / RoxyBrowser / BitBrowser 全局代理入库、环境关联与浏览器内出口核对。
- 处理 AdsPower 本机回环代理误报与常驻 Xray sidecar。
- 为团队交接生成 runbook 和敏感信息清单。
- 将跨境工具的部署、验收、交接和日常维护沉淀为可复用 SOP。

## 核心能力

- 境外 VPS 与域名采购前规划清单（云厂商无关）。
- 目标主机身份确认和 SSH 纳管。
- DNS 与证书检查。
- x-ui 管理界面部署流程、面板入口和账号交接边界。
- 一键起节点引擎 `scripts/node-wizard.sh`（deploy/verify/panel-open/panel-close/links/rollback）。
- 3x-ui 3.x 链式出口工具 `scripts/xui_chain_egress.py`（dry-run、备份、幂等写入、强制重启、运行配置读回和端到端出口验收）。
- 公开/私有端口边界设计。
- 服务状态、日志、网络连通性和团队可用性验收。
- 本地 runbook 和敏感交付手册骨架生成。
- 指纹浏览器代理的“全局入库 -> 环境关联 -> 实际出口 -> 关联回读”验收 SOP。
- 变更前确认和回滚意识。

## 目录

```text
.
├── README.md
├── README.en.md
├── LICENSE
├── CHANGELOG.md
├── VERSION
├── docs/
│   └── superpowers/          # 一键引擎的设计 spec 与实施计划
├── references/
│   ├── documentation.md
│   ├── chain-egress.md
│   ├── fingerprint-browser-egress.md
│   ├── sop.md
│   └── verification.md
├── scripts/
│   ├── install.sh
│   ├── node-wizard.sh        # 一键起节点引擎入口
│   ├── xui_chain_egress.py   # 3x-ui 独立链式出口与本机 sidecar
│   ├── lib/                  # 引擎库（secrets/preflight/config/verify/deploy/panel/rollback…）
│   ├── render_node_materials.py
│   └── validate_skill_package.py
├── tests/                    # 零依赖 bash 测试（tests/run.sh 一键全跑）
└── skill/
    └── cross-border-ops-wizard/
        └── SKILL.md
```

## 快速检查

```bash
python3 scripts/validate_skill_package.py
python3 scripts/render_node_materials.py --help
python3 scripts/xui_chain_egress.py --help
tests/run.sh
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
