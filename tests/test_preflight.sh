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
