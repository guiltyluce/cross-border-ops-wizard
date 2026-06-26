#!/usr/bin/env bash
set -euo pipefail
HERE="${WIZARD_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)}"
if [ -z "${HERE:-}" ] || [ ! -f "$HERE/lib/common.sh" ]; then
  echo "[error] 找不到引擎 lib/。本引擎是多文件结构：请先把整个 scripts/ 目录同步到主机后在该目录运行，或设置 WIZARD_HOME=/path/to/scripts。" >&2
  exit 1
fi
. "$HERE/lib/common.sh"

usage(){ cat >&2 <<'EOF'
usage: node-wizard.sh <deploy|verify|panel-open|panel-close|links|rollback> --alias <name> [--domain <fqdn>] [--profile lighthouse|generic] [--role <name>]
EOF
}

CMD="${1:-}"; shift || true
ALIAS=""; DOMAIN=""; PROFILE="generic"; ROLE="proxy"
while [ $# -gt 0 ]; do
  case "$1" in
    --alias) shift; ALIAS="${1:-}";;
    --domain) shift; DOMAIN="${1:-}";;
    --profile) shift; PROFILE="${1:-generic}";;
    --role) shift; ROLE="${1:-proxy}";;
    *) echo "[error] unknown arg: $1" >&2; usage; exit 2;;
  esac
  shift || true
done

case "$CMD" in
  deploy|verify|panel-open|panel-close|links|rollback) ;;
  *) echo "[error] unknown or missing subcommand: '$CMD'" >&2; usage; exit 2;;
esac
[ -n "$ALIAS" ] || { echo "[error] --alias is required" >&2; usage; exit 2; }

if [ "${WIZARD_SELFTEST:-0}" = "1" ]; then
  echo "cmd=$CMD alias=$ALIAS domain=$DOMAIN profile=$PROFILE role=$ROLE"
  exit 0
fi

# Load the rest of the libs and dispatch (implemented in later tasks).
for f in secrets links preflight config verify deploy panel rollback; do . "$HERE/lib/$f.sh"; done
case "$CMD" in
  deploy)      cmd_deploy ;;
  verify)      cmd_verify ;;
  panel-open)  cmd_panel_open ;;
  panel-close) cmd_panel_close ;;
  links)       cmd_links ;;
  rollback)    cmd_rollback ;;
esac
