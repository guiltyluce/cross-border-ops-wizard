#!/usr/bin/env bash
set -u
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/../scripts/lib/common.sh"
. "$(dirname "$0")/../scripts/lib/config.sh"

cfg="$(render_xray_config UUIDX PRIVX SIDX)"
assert_contains "xray port"   "$cfg" "\"port\": 443"
assert_contains "xray flow"   "$cfg" "xtls-rprx-vision"
assert_contains "xray reality" "$cfg" "\"security\": \"reality\""
assert_contains "xray uuid"   "$cfg" "UUIDX"
assert_contains "xray priv"   "$cfg" "PRIVX"
assert_contains "xray dest"   "$cfg" "www.microsoft.com:443"

ncfg="$(render_nginx_gateway n.example.com WEBPATH)"
assert_contains "nginx server_name" "$ncfg" "n.example.com"
assert_contains "nginx panel proxy" "$ncfg" "127.0.0.1:35179"
assert_contains "nginx random path" "$ncfg" "WEBPATH"
assert_contains "nginx listen gw"   "$ncfg" "listen 35178 ssl"

finish
