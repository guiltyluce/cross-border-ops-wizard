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

out="$(verify_summarize "a:0" "b:0"; echo "rc=$?")"
assert_contains "all fail rc" "$out" "rc=1"
assert_contains "all fail a" "$out" "a: FAIL"

finish
