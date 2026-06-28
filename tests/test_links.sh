#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/links.sh"

link="$(build_vless_link UUIDX HOSTX PUBKEYX SIDX)"
assert_contains "vless scheme"  "$link" "vless://UUIDX@HOSTX:443"
assert_contains "vless reality" "$link" "security=reality"
assert_contains "vless flow"    "$link" "flow=xtls-rprx-vision"
assert_contains "vless sni"     "$link" "sni=www.apple.com"
assert_contains "vless pbk"     "$link" "pbk=PUBKEYX"
assert_contains "vless sid"     "$link" "sid=SIDX"

REALITY_SNI=target.example.com
link_custom="$(build_vless_link UUIDX HOSTX PUBKEYX SIDX)"
assert_contains "vless custom sni" "$link_custom" "sni=target.example.com"

# 有域名 -> 订阅 URL 用域名网关
u="$(build_sub_url n.example.com PATHX)"
assert_eq "sub url" "$u" "https://n.example.com:35178/sub/PATHX"
# 无域名 -> 空（IP-only 不提供订阅 URL）
u="$(build_sub_url '' PATHX)"
assert_eq "sub url empty" "$u" ""

finish
