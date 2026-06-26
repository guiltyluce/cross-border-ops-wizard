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
