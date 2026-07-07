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
