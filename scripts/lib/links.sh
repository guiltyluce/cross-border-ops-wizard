#!/usr/bin/env bash
# Build client links from stored values. Source-only.

# build_vless_link <uuid> <host> <pubkey> <sid>
build_vless_link(){
  local uuid="$1" host="$2" pbk="$3" sid="$4"
  printf 'vless://%s@%s:%s?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=%s&fp=chrome&pbk=%s&sid=%s#%s' \
    "$uuid" "$host" "$PROXY_PORT" "$REALITY_SNI" "$pbk" "$sid" "$host"
}

# build_sub_url <domain-or-empty> <path>
build_sub_url(){
  local domain="$1" path="$2"
  [ -n "$domain" ] || { printf ''; return 0; }
  printf 'https://%s:%s/sub/%s' "$domain" "$GATEWAY_PORT" "$path"
}

cmd_links(){
  . "/root/ops-secrets/$ALIAS.env"
  build_vless_link "$UUID" "${DOMAIN:-$(self_ip)}" "$REALITY_PUBLIC" "$SHORT_ID"; echo
  local sub; sub="$(build_sub_url "$DOMAIN" "$WEB_PATH")"; [ -n "$sub" ] && echo "$sub"
}
