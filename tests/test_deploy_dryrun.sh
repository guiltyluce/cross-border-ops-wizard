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

# stubs: make preflight pass, deterministic secrets, avoid real writes
preflight_gate(){ return 0; }
gen_reality_keys(){ printf 'PRIV PUB'; }
gen_uuid(){ printf 'UUIDX'; }
gen_subid(){ printf 'sub-XXXX'; }
gen_path(){ printf 'PATHXXXXXXXX'; }
gen_basic_auth(){ printf 'opsadmin:HASH'; }
cmd_verify(){ echo "ALL PASS"; }
self_ip(){ printf '1.2.3.4'; }
ALIAS=t1; DOMAIN=n.example.com; PROFILE=generic; ROLE=proxy

out="$(DRY_RUN=1 deploy_run 2>&1)"
# phases appear in order
assert_contains "phase system"    "$out" "phase: system"
assert_contains "phase install"   "$out" "phase: install"
assert_contains "phase configure" "$out" "phase: configure"
assert_contains "phase firewall"  "$out" "phase: firewall"
# firewall opens 443 via run()
assert_contains "fw 443" "$out" "RUN:"
# private key must NOT appear anywhere in stdout/stderr (only public key in links; secrets file is redacted in dry-run)
assert_not_contains "no priv leak" "$out" "PRIV"

finish
