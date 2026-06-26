# One-Click Node Engine 实现计划（v0.3.0）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 `node-wizard.sh` —— 一个幂等、跨智能体、纯 bash 的"一键起节点"引擎，把新 VPS 变成 xray VLESS Reality 代理 + 默认本机绑定的 x-ui 后台。

**Architecture:** 单入口 `scripts/node-wizard.sh` 负责解析参数 + 派发子命令；逻辑拆进 `scripts/lib/*.sh`，每个文件单一职责、可被测试单独 source。纯逻辑（参数、秘密、链接、preflight 清单、verify 集计、配置渲染）用零依赖 bash 测试harness 做 TDD；副作用（装包/防火墙/证书）经 `run()` 包装，`DRY_RUN=1` 时只打印待执行命令，便于断言；真实部署用 `verify` 子命令在一次性 VPS 上做受入。

**Tech Stack:** Bash (4+)、xray-core(`xray x25519`/`xray uuid`)、x-ui/3x-ui、nginx、firewalld、acme/Let's Encrypt HTTP-01。测试：自带 `tests/lib.sh` 断言harness（无外部依赖，stock bash 可跑）。

参考权威设计：`docs/superpowers/specs/2026-06-25-one-click-engine-design.md`。

---

## 文件结构

```text
scripts/
  node-wizard.sh        # 入口：parse_args + 子命令派发
  lib/
    common.sh           # 常量(端口)、log/die、run(DRY_RUN 包装)、redact
    secrets.sh          # 生成 per-node 随机值 + reality 密钥对
    links.sh            # 由 env 组装 VLESS / 订阅链接
    preflight.sh        # DNS 指向自己 / 端口可达 检查 + 闸门 + 清单渲染
    config.sh           # 渲染 xray reality 配置 + nginx 网关配置
    verify.sh           # 各项验收检查 + PASS/FAIL 集计
    deploy.sh           # deploy 各阶段编排（经 run()）
    panel.sh            # panel-open / panel-close
    rollback.sh         # 拆除 deploy 创建物
tests/
  lib.sh                # 断言harness（assert_eq / assert_contains / assert_status）
  run.sh                # 跑全部 tests/test_*.sh
  test_args.sh
  test_secrets.sh
  test_links.sh
  test_preflight.sh
  test_config.sh
  test_verify.sh
  test_deploy_dryrun.sh
  test_redact.sh
```

约定：`lib/*.sh` 只定义函数、source 时无副作用。所有外部副作用调用都走 `run`，`DRY_RUN=1` 时打印 `RUN: <cmd>` 而不执行。

---

## Task 1: 测试harness 与 common.sh

**Files:**
- Create: `tests/lib.sh`
- Create: `tests/run.sh`
- Create: `scripts/lib/common.sh`
- Test: `tests/test_redact.sh`

- [ ] **Step 1: 写测试harness**

`tests/lib.sh`：
```bash
#!/usr/bin/env bash
# Minimal zero-dependency assert harness.
TESTS_RUN=0; TESTS_FAILED=0
_fail(){ TESTS_FAILED=$((TESTS_FAILED+1)); printf 'FAIL: %s\n' "$1" >&2; }
assert_eq(){ TESTS_RUN=$((TESTS_RUN+1)); [ "$2" = "$3" ] || _fail "$1: expected [$3] got [$2]"; }
assert_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$2" in *"$3"*) ;; *) _fail "$1: [$2] does not contain [$3]";; esac; }
assert_not_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$2" in *"$3"*) _fail "$1: [$2] unexpectedly contains [$3]";; esac; }
assert_status(){ TESTS_RUN=$((TESTS_RUN+1)); [ "$2" = "$3" ] || _fail "$1: expected exit [$3] got [$2]"; }
finish(){ printf '%s run, %s failed\n' "$TESTS_RUN" "$TESTS_FAILED"; [ "$TESTS_FAILED" -eq 0 ]; }
```

`tests/run.sh`：
```bash
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
rc=0
for t in test_*.sh; do
  echo "== $t =="
  bash "$t" || rc=1
done
exit $rc
```

- [ ] **Step 2: 写 common.sh 的失败测试**

`tests/test_redact.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"

# redact 把疑似私钥/密码替换为 ****
out="$(redact 'privateKey=ABCD1234 password=Sekret')"
assert_not_contains "redact key" "$out" "ABCD1234"
assert_not_contains "redact pw"  "$out" "Sekret"
assert_contains     "redact mask" "$out" "****"

# run 在 DRY_RUN 下只打印
out="$(DRY_RUN=1 run echo hello)"
assert_eq "dryrun prints" "$out" "RUN: echo hello"

# 端口常量已定义
assert_eq "proxy port"   "$PROXY_PORT" "443"
assert_eq "gateway port" "$GATEWAY_PORT" "35178"
assert_eq "panel port"   "$PANEL_PORT" "35179"

finish
```

- [ ] **Step 3: 跑测试确认失败**

Run: `bash tests/test_redact.sh`
Expected: FAIL（`common.sh` 不存在 / 函数未定义）

- [ ] **Step 4: 写 common.sh**

`scripts/lib/common.sh`：
```bash
#!/usr/bin/env bash
# Shared constants + helpers. Source-only, no side effects.
PROXY_PORT=443
GATEWAY_PORT=35178
PANEL_PORT=35179
SUB_BACKEND_PORT=2096
REALITY_SNI="${REALITY_SNI:-www.microsoft.com}"

log(){ printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die(){ printf '[error] %s\n' "$*" >&2; exit 1; }

# run: execute, or under DRY_RUN=1 just print the command.
run(){
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf 'RUN: %s\n' "$*"
  else
    "$@"
  fi
}

# redact: mask secret-looking key=value pairs for safe stdout.
redact(){
  printf '%s' "$1" | sed -E 's/(privateKey|password|publicKey|uuid|basic_pass)=[^ ]+/\1=****/g'
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `bash tests/test_redact.sh`
Expected: `... run, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add tests/lib.sh tests/run.sh scripts/lib/common.sh tests/test_redact.sh
git commit -m "feat(engine): test harness + common.sh (constants, run, redact)"
```

---

## Task 2: 参数解析与子命令派发

**Files:**
- Create: `scripts/node-wizard.sh`
- Test: `tests/test_args.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_args.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
WIZ="$(dirname "$0")/../scripts/node-wizard.sh"

# 缺 alias -> 退出码 2
out="$(bash "$WIZ" deploy 2>&1)"; st=$?
assert_status "missing alias" "$st" "2"
assert_contains "missing alias msg" "$out" "--alias"

# 未知子命令 -> 退出码 2
bash "$WIZ" frobnicate >/dev/null 2>&1; assert_status "unknown cmd" "$?" "2"

# WIZARD_SELFTEST=1 时只回显解析结果，不执行
out="$(WIZARD_SELFTEST=1 bash "$WIZ" deploy --alias t1 --domain n.example.com --profile lighthouse)"
assert_contains "alias parsed"  "$out" "alias=t1"
assert_contains "domain parsed" "$out" "domain=n.example.com"
assert_contains "profile parsed" "$out" "profile=lighthouse"
assert_contains "cmd parsed"    "$out" "cmd=deploy"

# profile 默认 generic
out="$(WIZARD_SELFTEST=1 bash "$WIZ" deploy --alias t1)"
assert_contains "default profile" "$out" "profile=generic"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_args.sh`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 写 node-wizard.sh**

`scripts/node-wizard.sh`：
```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/common.sh"

usage(){ cat >&2 <<'EOF'
usage: node-wizard.sh <deploy|verify|panel-open|panel-close|links|rollback> --alias <name> [--domain <fqdn>] [--profile lighthouse|generic] [--role <name>]
EOF
}

CMD="${1:-}"; shift || true
ALIAS=""; DOMAIN=""; PROFILE="generic"; ROLE="proxy"
while [ $# -gt 0 ]; do
  case "$1" in
    --alias) shift; ALIAS="${1:-}";;
    --domain) shift; DOMAIN="${1:-}";;
    --profile) shift; PROFILE="${1:-generic}";;
    --role) shift; ROLE="${1:-proxy}";;
    *) echo "[error] unknown arg: $1" >&2; usage; exit 2;;
  esac
  shift || true
done

case "$CMD" in
  deploy|verify|panel-open|panel-close|links|rollback) ;;
  *) echo "[error] unknown or missing subcommand: '$CMD'" >&2; usage; exit 2;;
esac
[ -n "$ALIAS" ] || { echo "[error] --alias is required" >&2; usage; exit 2; }

if [ "${WIZARD_SELFTEST:-0}" = "1" ]; then
  echo "cmd=$CMD alias=$ALIAS domain=$DOMAIN profile=$PROFILE role=$ROLE"
  exit 0
fi

# Load the rest of the libs and dispatch (implemented in later tasks).
for f in secrets links preflight config verify deploy panel rollback; do . "$HERE/lib/$f.sh"; done
case "$CMD" in
  deploy)      cmd_deploy ;;
  verify)      cmd_verify ;;
  panel-open)  cmd_panel_open ;;
  panel-close) cmd_panel_close ;;
  links)       cmd_links ;;
  rollback)    cmd_rollback ;;
esac
```

> 注意：Step 3 引用了后续任务才创建的 `lib/*.sh`。在 Task 2 阶段，`WIZARD_SELFTEST=1` 路径在 source 之前 `exit 0`，所以参数测试不依赖这些文件。为让脚本在缺文件时不报错，先创建占位空文件：`for f in secrets links preflight config verify deploy panel rollback; do : > scripts/lib/$f.sh; done`（后续任务逐个填充）。

- [ ] **Step 4: 创建占位 lib 文件并跑测试**

Run:
```bash
mkdir -p scripts/lib
for f in secrets links preflight config verify deploy panel rollback; do [ -f scripts/lib/$f.sh ] || printf '#!/usr/bin/env bash\n' > scripts/lib/$f.sh; done
chmod +x scripts/node-wizard.sh
bash tests/test_args.sh
```
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/node-wizard.sh scripts/lib/*.sh tests/test_args.sh
git commit -m "feat(engine): arg parsing + subcommand dispatch skeleton"
```

---

## Task 3: secrets.sh —— per-node 随机值与 reality 密钥

**Files:**
- Modify: `scripts/lib/secrets.sh`
- Test: `tests/test_secrets.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_secrets.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/secrets.sh"

# 随机路径：12 位字母数字
p="$(gen_path)"; assert_eq "path len" "${#p}" "12"
case "$p" in *[!a-zA-Z0-9]*) _fail "path charset: $p";; esac; TESTS_RUN=$((TESTS_RUN+1))

# subid：sub- 前缀 + 16 hex
s="$(gen_subid)"; assert_contains "subid prefix" "$s" "sub-"

# basic auth：user:passhash 形式（htpasswd bcrypt 以 \$2 开头）；此处用占位 hasher 注入
hash_password(){ printf 'HASHED(%s)' "$1"; }   # 测试用桩
ba="$(gen_basic_auth opsadmin)"
assert_contains "basic user" "$ba" "opsadmin:"
assert_contains "basic hashed" "$ba" "HASHED("

# reality 密钥：用桩 xray 注入，验证解析出 private/public
xray(){ [ "$1" = "x25519" ] && printf 'Private key: PRIV111\nPublic key: PUB222\n'; }
export -f xray
read -r priv pub < <(gen_reality_keys)
assert_eq "reality priv" "$priv" "PRIV111"
assert_eq "reality pub"  "$pub"  "PUB222"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_secrets.sh`
Expected: FAIL（函数未定义）

- [ ] **Step 3: 写 secrets.sh**

`scripts/lib/secrets.sh`：
```bash
#!/usr/bin/env bash
# Per-node secret generation. Source-only.

_rand_alnum(){ LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$1"; }

gen_path(){ _rand_alnum 12; }
gen_subid(){ printf 'sub-%s' "$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 16)"; }
gen_uuid(){ if command -v xray >/dev/null 2>&1; then xray uuid; else cat /proc/sys/kernel/random/uuid; fi; }

# hash_password may be overridden in tests; default uses htpasswd bcrypt.
hash_password(){ htpasswd -nbBC 10 "x" "$1" | cut -d: -f2; }
gen_basic_auth(){ local user="$1"; printf '%s:%s' "$user" "$(hash_password "$(_rand_alnum 20)")"; }

# gen_reality_keys -> "<private> <public>"
gen_reality_keys(){
  local out priv pub
  out="$(xray x25519)"
  priv="$(printf '%s' "$out" | sed -n 's/.*[Pp]rivate key: *//p')"
  pub="$(printf '%s' "$out" | sed -n 's/.*[Pp]ublic key: *//p')"
  printf '%s %s' "$priv" "$pub"
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_secrets.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/secrets.sh tests/test_secrets.sh
git commit -m "feat(engine): per-node secret + reality key generation"
```

---

## Task 4: links.sh —— 组装 VLESS / 订阅链接

**Files:**
- Modify: `scripts/lib/links.sh`
- Test: `tests/test_links.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_links.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/links.sh"

link="$(build_vless_link UUIDX HOSTX PUBKEYX SIDX)"
assert_contains "vless scheme"  "$link" "vless://UUIDX@HOSTX:443"
assert_contains "vless reality" "$link" "security=reality"
assert_contains "vless flow"    "$link" "flow=xtls-rprx-vision"
assert_contains "vless sni"     "$link" "sni=www.microsoft.com"
assert_contains "vless pbk"     "$link" "pbk=PUBKEYX"
assert_contains "vless sid"     "$link" "sid=SIDX"

# 有域名 -> 订阅 URL 用域名网关
u="$(build_sub_url n.example.com PATHX)"
assert_eq "sub url" "$u" "https://n.example.com:35178/sub/PATHX"
# 无域名 -> 空（IP-only 不提供订阅 URL）
u="$(build_sub_url '' PATHX)"
assert_eq "sub url empty" "$u" ""

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_links.sh`
Expected: FAIL

- [ ] **Step 3: 写 links.sh**

`scripts/lib/links.sh`：
```bash
#!/usr/bin/env bash
# Build client links from stored values. Source-only.

# build_vless_link <uuid> <host> <pubkey> <sid>
build_vless_link(){
  local uuid="$1" host="$2" pbk="$3" sid="$4"
  printf 'vless://%s@%s:%s?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=%s&fp=chrome&pbk=%s&sid=%s#%s' \
    "$uuid" "$host" "$PROXY_PORT" "$REALITY_SNI" "$pbk" "$sid" "$host"
}

# build_sub_url <domain-or-empty> <path>
build_sub_url(){
  local domain="$1" path="$2"
  [ -n "$domain" ] || { printf ''; return 0; }
  printf 'https://%s:%s/sub/%s' "$domain" "$GATEWAY_PORT" "$path"
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_links.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/links.sh tests/test_links.sh
git commit -m "feat(engine): VLESS / subscription link assembly"
```

---

## Task 5: preflight.sh —— 检查、闸门、清单

**Files:**
- Modify: `scripts/lib/preflight.sh`
- Test: `tests/test_preflight.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_preflight.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/preflight.sh"

# 桩：dns_resolve / tcp_open 可注入
dns_resolve(){ printf '1.2.3.4'; }          # 域名解析到 1.2.3.4
self_ip(){ printf '1.2.3.4'; }              # 本机也是 1.2.3.4 -> 匹配
tcp_open(){ return 0; }                      # 端口都通
out="$(preflight_gate n.example.com 80 443; echo "rc=$?")"
assert_contains "ready ok" "$out" "rc=0"

# DNS 不匹配 -> 退出非0 + 清单含 A 记录提示
dns_resolve(){ printf '9.9.9.9'; }
out="$(preflight_gate n.example.com 80 443 2>&1; echo "rc=$?")"
assert_contains "dns fail rc" "$out" "rc=1"
assert_contains "dns checklist" "$out" "A 记录"

# 端口不通 -> 清单含端口提示
dns_resolve(){ printf '1.2.3.4'; }
tcp_open(){ [ "$2" = "443" ] && return 1 || return 0; }
out="$(preflight_gate n.example.com 80 443 2>&1; echo "rc=$?")"
assert_contains "port fail rc" "$out" "rc=1"
assert_contains "port checklist" "$out" "443"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_preflight.sh`
Expected: FAIL

- [ ] **Step 3: 写 preflight.sh**

`scripts/lib/preflight.sh`：
```bash
#!/usr/bin/env bash
# Preflight gate. Pure orchestration; dns_resolve/self_ip/tcp_open are overridable.

dns_resolve(){ dig +short "$1" A | tail -n1; }
self_ip(){ curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'; }
tcp_open(){ nc -z -G 5 "$1" "$2" >/dev/null 2>&1; }   # tcp_open <ip> <port>

# preflight_gate <domain-or-empty> <port>...
# returns 0 if ready; otherwise prints a checklist to stderr and returns 1.
preflight_gate(){
  local domain="$1"; shift
  local ports="$*" ip ready=0 lines=""
  ip="$(self_ip)"
  if [ -n "$domain" ]; then
    local resolved; resolved="$(dns_resolve "$domain")"
    if [ "$resolved" != "$ip" ]; then
      ready=1
      lines="${lines}- 在 DNS 服务商添加/修正 A 记录： ${domain}  A  ${ip}（当前解析=${resolved:-无}）\n"
    fi
  fi
  local p
  for p in $ports; do
    if ! tcp_open "$ip" "$p"; then
      ready=1
      lines="${lines}- 在云防火墙（如腾讯轻量控制台）放行 TCP 端口 ${p}\n"
    fi
  done
  if [ "$ready" != "0" ]; then
    printf '[preflight] 还差以下人工云操作，做完后重跑 deploy：\n' >&2
    printf "$lines" >&2
    return 1
  fi
  return 0
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_preflight.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/preflight.sh tests/test_preflight.sh
git commit -m "feat(engine): preflight gate + actionable checklist"
```

---

## Task 6: config.sh —— 渲染 xray / nginx 配置

**Files:**
- Modify: `scripts/lib/config.sh`
- Test: `tests/test_config.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_config.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/config.sh"

cfg="$(render_xray_config UUIDX PRIVX SIDX)"
assert_contains "xray port"   "$cfg" "\"port\": 443"
assert_contains "xray flow"   "$cfg" "xtls-rprx-vision"
assert_contains "xray reality" "$cfg" "\"security\": \"reality\""
assert_contains "xray uuid"   "$cfg" "UUIDX"
assert_contains "xray priv"   "$cfg" "PRIVX"
assert_contains "xray dest"   "$cfg" "www.microsoft.com:443"

ncfg="$(render_nginx_gateway n.example.com WEBPATH)"
assert_contains "nginx server_name" "$ncfg" "n.example.com"
assert_contains "nginx panel proxy" "$ncfg" "127.0.0.1:35179"
assert_contains "nginx random path" "$ncfg" "WEBPATH"
assert_contains "nginx listen gw"   "$ncfg" "listen 35178 ssl"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_config.sh`
Expected: FAIL

- [ ] **Step 3: 写 config.sh**

`scripts/lib/config.sh`：
```bash
#!/usr/bin/env bash
# Config renderers. Pure string output, no writes.

# render_xray_config <uuid> <private_key> <short_id>
render_xray_config(){
  local uuid="$1" priv="$2" sid="$3"
  cat <<EOF
{
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": { "clients": [{ "id": "$uuid", "flow": "xtls-rprx-vision" }], "decryption": "none" },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "$REALITY_SNI:443",
        "serverNames": ["$REALITY_SNI"],
        "privateKey": "$priv",
        "shortIds": ["$sid"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
}

# render_nginx_gateway <domain> <web_path>
render_nginx_gateway(){
  local domain="$1" web="$2"
  cat <<EOF
server {
  listen 35178 ssl;
  server_name $domain;
  ssl_certificate     /root/cert/$domain/fullchain.pem;
  ssl_certificate_key /root/cert/$domain/privkey.pem;
  location = /healthz { return 200 'ok'; }
  location /$web/ {
    auth_basic "ops";
    auth_basic_user_file /etc/nginx/ops.htpasswd;
    proxy_pass https://127.0.0.1:35179/;
    proxy_ssl_verify off;
  }
}
EOF
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_config.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/config.sh tests/test_config.sh
git commit -m "feat(engine): xray reality + nginx gateway config renderers"
```

---

## Task 7: verify.sh —— 验收检查与集计

**Files:**
- Modify: `scripts/lib/verify.sh`
- Test: `tests/test_verify.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_verify.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/verify.sh"

# summarize：全 true -> ALL PASS 退出0
out="$(verify_summarize "services:1" "reality443:1" "bbr:1"; echo "rc=$?")"
assert_contains "all pass" "$out" "ALL PASS"
assert_contains "all pass rc" "$out" "rc=0"

# 有一个失败 -> 列出 FAIL 项 + 退出1
out="$(verify_summarize "services:1" "reality443:0" "bbr:1"; echo "rc=$?")"
assert_contains "has fail" "$out" "reality443: FAIL"
assert_contains "fail rc" "$out" "rc=1"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_verify.sh`
Expected: FAIL

- [ ] **Step 3: 写 verify.sh**

`scripts/lib/verify.sh`：
```bash
#!/usr/bin/env bash
# Acceptance checks + aggregation.

# verify_summarize "name:1" "name:0" ...  -> prints table, returns 0 if all 1.
verify_summarize(){
  local item name ok all=0
  for item in "$@"; do
    name="${item%%:*}"; ok="${item##*:}"
    if [ "$ok" = "1" ]; then printf '  %-14s OK\n' "$name"; else printf '  %-14s FAIL\n' "$name"; all=1; fi
  done
  if [ "$all" = "0" ]; then echo "ALL PASS"; return 0; else echo "RESULT: FAIL"; return 1; fi
}

# Live checks (used by cmd_verify on a real host).
check_services(){ systemctl is-active --quiet x-ui nginx firewalld sshd && echo 1 || echo 0; }
check_reality443(){ ss -ltn '( sport = :443 )' | grep -q ':443' && echo 1 || echo 0; }
check_panel_local(){ ss -ltn | grep -q '127.0.0.1:35179' && echo 1 || echo 0; }
check_bbr(){ [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ] && echo 1 || echo 0; }

cmd_verify(){
  verify_summarize \
    "services:$(check_services)" \
    "reality443:$(check_reality443)" \
    "panel_local:$(check_panel_local)" \
    "bbr:$(check_bbr)"
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_verify.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/verify.sh tests/test_verify.sh
git commit -m "feat(engine): verify checks + PASS/FAIL aggregation"
```

---

## Task 8: deploy.sh —— 阶段编排（DRY_RUN 可断言）

**Files:**
- Modify: `scripts/lib/deploy.sh`
- Test: `tests/test_deploy_dryrun.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_deploy_dryrun.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/secrets.sh"
. "$(dirname "$0")/../scripts/lib/links.sh"
. "$(dirname "$0")/../scripts/lib/preflight.sh"
. "$(dirname "$0")/../scripts/lib/config.sh"
. "$(dirname "$0")/../scripts/lib/verify.sh"
. "$(dirname "$0")/../scripts/lib/deploy.sh"

# 桩：让 preflight 通过、密钥确定、跳过真实写入
preflight_gate(){ return 0; }
gen_reality_keys(){ printf 'PRIV PUB'; }
gen_uuid(){ printf 'UUIDX'; }
gen_subid(){ printf 'sub-XXXX'; }
gen_path(){ printf 'PATHXXXXXXXX'; }
gen_basic_auth(){ printf 'opsadmin:HASH'; }
ALIAS=t1; DOMAIN=n.example.com; PROFILE=generic; ROLE=proxy

out="$(DRY_RUN=1 deploy_run 2>&1)"
# 阶段按顺序出现
assert_contains "phase system"   "$out" "phase: system"
assert_contains "phase install"  "$out" "phase: install"
assert_contains "phase configure" "$out" "phase: configure"
assert_contains "phase firewall" "$out" "phase: firewall"
# 防火墙放行 443 经 run() 打印
assert_contains "fw 443" "$out" "RUN:"
# 私钥不出现在最终链接打印里
assert_not_contains "no priv in links" "$out" "PRIV"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_deploy_dryrun.sh`
Expected: FAIL

- [ ] **Step 3: 写 deploy.sh**

`scripts/lib/deploy.sh`：
```bash
#!/usr/bin/env bash
# Deploy orchestration. Side effects go through run().

phase(){ log "phase: $1"; }

deploy_system(){
  phase system
  run sysctl -w net.core.default_qdisc=fq
  run sysctl -w net.ipv4.tcp_congestion_control=bbr
  run bash -c 'command -v nginx >/dev/null || (yum -y install nginx firewalld socat sqlite httpd-tools || apt-get -y install nginx firewalld socat sqlite apache2-utils)'
}
deploy_install(){
  phase install
  run bash -c 'command -v x-ui >/dev/null || bash <(curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) </dev/null'
}
deploy_configure(){
  phase configure
  read -r PRIV PUB <<<"$(gen_reality_keys)"
  UUID="$(gen_uuid)"; SID="$(gen_subid)"; WEBPATH="$(gen_path)"; BASIC="$(gen_basic_auth opsadmin)"
  run bash -c "umask 077; mkdir -p /root/ops-secrets /usr/local/x-ui/bin"
  render_xray_config "$UUID" "$PRIV" "$SID" | run tee /usr/local/x-ui/bin/config.json >/dev/null
  run x-ui restart
}
deploy_cert(){
  [ -n "$DOMAIN" ] || { log "phase: cert (skipped, no domain)"; return 0; }
  phase cert
  run bash -c "mkdir -p /root/cert/$DOMAIN"
  run bash -c "command -v ~/.acme.sh/acme.sh >/dev/null || curl -fsSL https://get.acme.sh | sh -s email=ops@$DOMAIN"
  run ~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --httpport 80
  run ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --key-file "/root/cert/$DOMAIN/privkey.pem" --fullchain-file "/root/cert/$DOMAIN/fullchain.pem"
}
deploy_firewall(){
  phase firewall
  run firewall-cmd --permanent --add-port=443/tcp
  run firewall-cmd --permanent --add-service=ssh
  run firewall-cmd --permanent --add-service=http
  run firewall-cmd --reload
}
deploy_emit(){
  phase emit
  local link sub
  link="$(build_vless_link "$UUID" "${DOMAIN:-$(self_ip)}" "$PUB" "$SID")"
  sub="$(build_sub_url "$DOMAIN" "$WEBPATH")"
  run bash -c "umask 077; cat > /root/ops-secrets/$ALIAS.env <<EOF
ALIAS=$ALIAS
DOMAIN=$DOMAIN
UUID=$UUID
REALITY_PRIVATE=$PRIV
REALITY_PUBLIC=$PUB
SHORT_ID=$SID
WEB_PATH=$WEBPATH
BASIC_AUTH=$BASIC
EOF"
  echo "面板：默认仅本机(127.0.0.1:35179)，SSH 隧道访问；需要时 panel-open"
  [ -n "$sub" ] && echo "订阅：$sub"
  echo "VLESS：$link"
}

deploy_run(){
  local ports="80 443"
  preflight_gate "$DOMAIN" $ports || return 1
  deploy_system; deploy_install; deploy_configure; deploy_cert; deploy_firewall
  cmd_verify || log "verify reported FAIL"
  deploy_emit
}
cmd_deploy(){ deploy_run; }
```

> 备注：`deploy_emit` 打印的 VLESS 链接只含 **public** key（`$PUB`），私钥 `$PRIV` 只写进 600 的 env 文件、不进 stdout —— 测试 `no priv in links` 守这条。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_deploy_dryrun.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/deploy.sh tests/test_deploy_dryrun.sh
git commit -m "feat(engine): deploy phase orchestration (dry-run testable)"
```

---

## Task 9: panel.sh —— 按需开关公网后台

**Files:**
- Modify: `scripts/lib/panel.sh`
- Test: 追加到 `tests/test_deploy_dryrun.sh`（同 source 集合）

- [ ] **Step 1: 写失败测试**

新建 `tests/test_panel.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/preflight.sh"
. "$(dirname "$0")/../scripts/lib/config.sh"
. "$(dirname "$0")/../scripts/lib/panel.sh"

preflight_gate(){ return 0; }
ALIAS=t1; DOMAIN=n.example.com; WEB_PATH=PATHXXXXXXXX
# env 读取桩
load_node_env(){ :; }

out="$(DRY_RUN=1 cmd_panel_open 2>&1)"
assert_contains "open gw 35178" "$out" "35178/tcp"
assert_contains "open reload"   "$out" "RUN: firewall-cmd --reload"

# 无域名 -> 拒绝开放
DOMAIN=""
out="$(cmd_panel_open 2>&1; echo rc=$?)"
assert_contains "open needs domain" "$out" "rc=1"

DOMAIN=n.example.com
out="$(DRY_RUN=1 cmd_panel_close 2>&1)"
assert_contains "close removes 35178" "$out" "--remove-port=35178/tcp"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_panel.sh`
Expected: FAIL

- [ ] **Step 3: 写 panel.sh**

`scripts/lib/panel.sh`：
```bash
#!/usr/bin/env bash
# On-demand public admin gateway toggle.

load_node_env(){ . "/root/ops-secrets/$ALIAS.env"; }

cmd_panel_open(){
  [ -n "$DOMAIN" ] || { echo "[error] panel-open 需要 --domain（IP-only 节点请用 SSH 隧道访问后台）" >&2; return 1; }
  load_node_env
  preflight_gate "$DOMAIN" "$GATEWAY_PORT" || return 1
  render_nginx_gateway "$DOMAIN" "$WEB_PATH" | run tee /etc/nginx/conf.d/ops-gateway.conf >/dev/null
  run firewall-cmd --permanent --add-port=35178/tcp
  run firewall-cmd --reload
  run nginx -s reload
  echo "面板已临时开放： https://$DOMAIN:$GATEWAY_PORT/$WEB_PATH/"
}

cmd_panel_close(){
  run rm -f /etc/nginx/conf.d/ops-gateway.conf
  run firewall-cmd --permanent --remove-port=35178/tcp
  run firewall-cmd --reload
  run nginx -s reload
  echo "面板公网入口已关闭"
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_panel.sh`
Expected: `... run, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/panel.sh tests/test_panel.sh
git commit -m "feat(engine): panel-open/panel-close on-demand gateway"
```

---

## Task 10: links 子命令 + rollback.sh

**Files:**
- Modify: `scripts/lib/links.sh`（追加 `cmd_links`）
- Modify: `scripts/lib/rollback.sh`
- Test: `tests/test_rollback.sh`

- [ ] **Step 1: 写失败测试**

`tests/test_rollback.sh`：
```bash
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/rollback.sh"
ALIAS=t1

out="$(DRY_RUN=1 cmd_rollback 2>&1)"
assert_contains "stop xui"   "$out" "x-ui stop"
assert_contains "rm gateway" "$out" "ops-gateway.conf"
assert_contains "close 443"  "$out" "--remove-port=443/tcp"
assert_contains "rm secrets" "$out" "/root/ops-secrets/t1.env"

finish
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tests/test_rollback.sh`
Expected: FAIL

- [ ] **Step 3: 写 rollback.sh 与 cmd_links**

`scripts/lib/rollback.sh`：
```bash
#!/usr/bin/env bash
# Tear down what deploy created.
cmd_rollback(){
  run x-ui stop || true
  run rm -f /etc/nginx/conf.d/ops-gateway.conf
  run firewall-cmd --permanent --remove-port=443/tcp || true
  run firewall-cmd --permanent --remove-port=35178/tcp || true
  run firewall-cmd --reload || true
  run rm -f "/root/ops-secrets/$ALIAS.env"
  echo "已回滚 $ALIAS（x-ui 二进制与系统包保留，避免误删共享依赖）"
}
```

在 `scripts/lib/links.sh` 末尾追加：
```bash
cmd_links(){
  . "/root/ops-secrets/$ALIAS.env"
  build_vless_link "$UUID" "${DOMAIN:-$(self_ip)}" "$REALITY_PUBLIC" "$SHORT_ID"; echo
  local sub; sub="$(build_sub_url "$DOMAIN" "$WEB_PATH")"; [ -n "$sub" ] && echo "$sub"
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tests/test_rollback.sh && bash tests/run.sh`
Expected: 全部 `0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/rollback.sh scripts/lib/links.sh tests/test_rollback.sh
git commit -m "feat(engine): links subcommand + rollback"
```

---

## Task 11: 接入 skill 包 + 升版 v0.3.0 + 文档

**Files:**
- Modify: `skill/cross-border-ops-wizard/SKILL.md`
- Modify: `CHANGELOG.md`
- Modify: `README.md` / `README.en.md`

- [ ] **Step 1: SKILL.md 引用引擎 + 升版**

把 frontmatter `version: 0.2.0` 改为 `version: 0.3.0`；在「工作流程」步骤 3 后补一行：
```text
   - 一键部署可用 `scripts/node-wizard.sh deploy --alias <a> [--domain <d>]`（幂等；preflight 不过会给云操作清单并退出，修好重跑）。
```
并在「关键命令」补：
```text
一键起节点 / 验收 / 开关后台：

\`\`\`bash
ssh <alias> 'bash -s' < scripts/node-wizard.sh deploy --alias <a> --domain <d>
ssh <alias> 'bash -s' < scripts/node-wizard.sh verify --alias <a>
ssh <alias> 'bash -s' < scripts/node-wizard.sh panel-open --alias <a> --domain <d>
\`\`\`
```

- [ ] **Step 2: 跑 validator 确认引用与打包正常**

Run: `python3 scripts/validate_skill_package.py`
Expected: `[ok] cross-border-ops-wizard skill package validated`
（validator 会校验 SKILL.md 引用的 `scripts/node-wizard.sh` 在包内）

- [ ] **Step 3: 更新 CHANGELOG.md**

在顶部加：
```markdown
## [0.3.0] - 2026-06-26

### Added
- `scripts/node-wizard.sh` one-click engine: `deploy/verify/panel-open/panel-close/links/rollback`.
- Idempotent provisioning of xray VLESS Reality (443) + x-ui panel bound to localhost.
- Semi-auto preflight gate (DNS + cloud firewall) with actionable checklist.
- Zero-dependency bash test harness under `tests/`.
```

- [ ] **Step 4: 跑全部测试**

Run: `bash tests/run.sh`
Expected: 每个文件 `0 failed`

- [ ] **Step 5: Commit + tag**

```bash
git add -A
git commit -m "feat(engine): wire node-wizard into skill, bump v0.3.0"
git tag -a v0.3.0 -m "v0.3.0: one-click node-wizard engine"
```

---

## Task 12: 真机受入（手动，一次性 VPS）

**Files:** 无（手动验收，结果记入 runbook）

- [ ] **Step 1:** 开一台一次性 VPS，配好 DNS A 记录 + 云防火墙放行 80/443。
- [ ] **Step 2:** `ssh <alias> 'bash -s' < scripts/node-wizard.sh deploy --alias accept-test --domain test.example.com`
  Expected: 走到 `ALL PASS`，打印订阅 + VLESS。
- [ ] **Step 3:** 重跑同一条 deploy。Expected: 无破坏性变更，仍 `ALL PASS`（验证幂等）。
- [ ] **Step 4:** 故意把 DNS 指错，重跑。Expected: 打印 A 记录清单并非0退出，不留半成品。
- [ ] **Step 5:** `panel-open` 后浏览器访问网关（401 未授权 / 带 basic-auth 200），`panel-close` 后 `nc -z <ip> 35178` 失败。
- [ ] **Step 6:** 用一个客户端导入订阅，确认能连、能上网。
- [ ] **Step 7:** `rollback --alias accept-test`，确认公网无残留监听。
- [ ] **Step 8:** 确认全程 stdout 无私钥/密码（`deploy ... | grep -i privateKey` 应为空）。
- [ ] **Step 9:** 通过后 `git push origin main --tags`。

---

## 自查（spec 覆盖 / 占位符 / 类型一致）

- **spec 覆盖**：六个子命令✅(Task2/7/8/9/10)；preflight 半自动闸门✅(Task5/8)；面板默认本机 + 按需网关✅(Task6/9)；per-node 秘密✅(Task3)；幂等✅(deploy 检测/重跑, Task8/12)；回滚✅(Task10)；秘密文件 600 + 不打印私钥✅(Task8 emit + test)；跨 agent 打包✅(Task11)；验收标准✅(Task12)。
- **占位符**：无 TBD/TODO；每个 code step 给了完整代码。
- **类型/命名一致**：`gen_reality_keys`→"PRIV PUB"、`build_vless_link <uuid> <host> <pubkey> <sid>`、`build_sub_url <domain> <path>`、`preflight_gate <domain> <port...>`、`verify_summarize "name:0/1"`、env 字段 `UUID/REALITY_PRIVATE/REALITY_PUBLIC/SHORT_ID/WEB_PATH/BASIC_AUTH` 在 Task8 写入与 Task10 读取一致。
