---
name: cross-border-ops-wizard
version: 0.2.0
description: Use when turning a freshly provisioned overseas VPS into a working proxy node with an x-ui/3x-ui admin panel and team subscriptions. 触发：新 VPS 搭代理、部署 x-ui/3x-ui 面板、配置 DNS/证书/HTTPS 网关/防火墙边界、分发 VLESS/Reality 订阅、生成交付 runbook 与敏感手册；排查节点不可达、证书异常、端口不通、面板打不开、下载慢/丢包/线路差。适用任意云厂商（腾讯云 Lighthouse 为内置 profile），适配 Claude Code、Codex、WorkBuddy、OpenClaw 等智能体。
---

# VPS 运维纳管魔法师 (cross-border-ops-wizard)

GitHub: [guiltyluce/cross-border-ops-wizard](https://github.com/guiltyluce/cross-border-ops-wizard)

把一台**刚开好的境外 VPS** 从“裸机”推进到“x-ui/3x-ui 面板可用、团队能接入 VLESS/Reality 订阅、后续可维护”的状态。覆盖采购信息确认、主机纳管、DNS、证书、x-ui 部署、网关入口、端口边界、稳定性/线路检查和交接文档。

- **云厂商无关**：主流程不绑定具体厂商。腾讯云 Lighthouse 作为内置 profile（注意其云防火墙独立于系统防火墙、需在控制台单独放行，默认网卡 MTU 常为 8500）；其他云按同一套元组纳管。
- **跨智能体**：本 SKILL.md 为标准格式，可装入 Claude Code / Codex / WorkBuddy / OpenClaw 的 skills 目录（见仓库 `scripts/install.sh`）。执行类操作统一放在 `scripts/` 下的纯 bash / python，不依赖某个 agent 的专有工具。

# 触发场景

用户出现以下意图时使用：

- 手头有一台新开的境外 VPS（任意云厂商），想搭代理 + 管理后台。
- 同时有域名，需要把域名解析、证书和 VPS 服务串起来（无域名时可走纯 IP 简化路径）。
- 希望部署 x-ui / 3x-ui 管理界面，方便团队接入、维护跨境工具。
- 配置 DNS、证书、HTTPS 网关、面板入口和健康检查。
- 排查节点不可达、证书异常、端口不通、面板不可访问、下载慢/丢包/线路差。
- 生成运维 runbook、交付手册、敏感信息清单。
- 对已有节点做阶段性验收和交接。

# 工作原则

- 先读后改：先确认目标主机、云厂商、区域、IP、域名、SSH alias 和用途。
- 一次只处理一个明确目标，旧节点默认只读。
- 云防火墙、系统防火墙、证书、账号和密钥操作前先确认。
- 敏感信息不进 git。真实密钥、x-ui 后台地址、一次性链接和账号密码只写入本地受控文件或用户指定的安全位置。
- 交付材料分层：公开 runbook 写结构和检查方法；敏感手册只在用户明确要求时写入凭据。

# 工作流程

1. 规划：
   - 明确用途、云厂商与区域、预算、域名、管理员、团队人数、交付范围。
   - 参考 `references/sop.md`。
2. 纳管：
   - 记录 provider、region、instance_id、public_ip、os、domain、alias、role。
   - 验证 SSH、DNS 和基础系统信息。
3. x-ui、网关与证书：
   - 配置域名解析。
   - 按目标系统安装并初始化 x-ui / 3x-ui 管理界面。
   - 配置 HTTP 健康检查、HTTPS 网关和面板入口。
   - 申请并验证证书。
4. 端口与边界：
   - 明确哪些端口公开，哪些只允许本机或内网访问。
   - 云防火墙与系统防火墙保持一致（Lighthouse 等需在控制台单独放行公网端口）。
5. 验收：
   - 参考 `references/verification.md` 执行服务、端口、HTTP/TLS、速度和日志检查。
   - 用户反馈“下载慢/卡”时，按 verification.md 的“线路与丢包诊断”分段定位（先排除服务端，再看 VPS↔客户端这一段的丢包/路由），不要只看客户端测速数字。
6. 文档：
   - 参考 `references/documentation.md` 输出 runbook、敏感交付手册和操作命令。
   - 使用 `scripts/render_node_materials.py` 生成本地材料骨架。

# 关键命令

生成节点材料骨架：

```bash
python3 scripts/render_node_materials.py \
  --alias team-sg \
  --domain node.example.com \
  --public-ip 203.0.113.10 \
  --out-dir ./output/team-sg
```

验收时至少检查：

- SSH 是否可登录。
- DNS 是否解析到目标 IP。
- x-ui 管理界面是否可登录。
- 健康检查是否返回成功。
- HTTPS 证书是否匹配域名。
- 公开端口和私有端口是否符合设计。
- 服务日志是否没有持续报错。

# 注意事项

- 不在最终回复中展示私钥、密码、订阅类链接或一次性 token。
- 不把真实节点材料提交到公开仓库。
- 没有用户确认时，不改云防火墙、不重启关键服务、不覆盖现有配置。
- 如果当前信息不足，先输出待确认清单和只读检查命令。
