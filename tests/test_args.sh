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
