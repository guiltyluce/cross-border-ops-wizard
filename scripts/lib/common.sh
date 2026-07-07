#!/usr/bin/env bash
# Shared constants + helpers. Source-only, no side effects.
PROXY_PORT=443
GATEWAY_PORT=35178
PANEL_PORT=35179
SUB_BACKEND_PORT=2096
REALITY_SNI="${REALITY_SNI:-www.apple.com}"
REALITY_DEST="${REALITY_DEST:-$REALITY_SNI:$PROXY_PORT}"

log(){ printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die(){ printf '[error] %s\n' "$*" >&2; exit 1; }

# run: execute, or under DRY_RUN=1 just print the command.
run(){
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf 'RUN:'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

# redact: mask secret-looking key=value pairs for safe stdout.
redact(){
  printf '%s' "$1" | sed -E 's/(privateKey|password|publicKey|uuid|basic_pass)=[^ ]+/\1=****/g'
}
