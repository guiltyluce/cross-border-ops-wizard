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
