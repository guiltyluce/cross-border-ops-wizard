#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"

root="$(cd "$(dirname "$0")/.." && pwd)"
ref="$root/references/fingerprint-browser-egress.md"
skill="$root/skill/cross-border-ops-wizard/SKILL.md"

[ -f "$ref" ] || _fail "missing fingerprint-browser egress reference"
TESTS_RUN=$((TESTS_RUN+1))

content="$(cat "$ref")"
assert_contains "global-first contract" "$content" "global proxy inventory"
assert_contains "in-browser verification" "$content" "fresh readback from inside the opened browser profile"
assert_contains "Roxy association check" "$content" "已关联窗口"
assert_contains "AdsPower workflow" "$content" "## 6. AdsPower"
assert_contains "skill routes to module" "$(cat "$skill")" "references/fingerprint-browser-egress.md"

if printf '%s\n' "$content" | grep -Eq '(^|[^0-9])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9]|$)'; then
  _fail "reference contains a literal IPv4 address"
else
  TESTS_RUN=$((TESTS_RUN+1))
fi

finish
