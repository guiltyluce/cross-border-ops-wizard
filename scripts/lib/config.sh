#!/usr/bin/env bash
# Config renderers. Pure string output, no writes.

# render_xray_config <uuid> <private_key> <short_id>
render_xray_config(){
  local uuid="$1" priv="$2" sid="$3"
  case "$uuid$priv$sid" in *[\`\$]*) die "render_xray_config: illegal characters in arguments";; esac
  cat <<EOF
{
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": { "clients": [{ "id": "$uuid", "flow": "xtls-rprx-vision" }], "decryption": "none" },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "$REALITY_SNI:443",
        "serverNames": ["$REALITY_SNI"],
        "privateKey": "$priv",
        "shortIds": ["$sid"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
}

# render_nginx_gateway <domain> <web_path>
render_nginx_gateway(){
  local domain="$1" web="$2"
  case "$domain$web" in *[\`\$]*) die "render_nginx_gateway: illegal characters in arguments";; esac
  cat <<EOF
server {
  listen 35178 ssl;
  server_name $domain;
  ssl_certificate     /root/cert/$domain/fullchain.pem;
  ssl_certificate_key /root/cert/$domain/privkey.pem;
  location = /healthz { return 200 'ok'; }
  location /sub/ {
    proxy_pass http://127.0.0.1:$SUB_BACKEND_PORT;
  }
  location /$web/ {
    auth_basic "ops";
    auth_basic_user_file /etc/nginx/ops.htpasswd;
    proxy_pass http://127.0.0.1:35179/;
  }
}
EOF
}
