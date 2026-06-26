#!/usr/bin/env bash
# Deploy orchestration. Side effects go through run(). Secrets never hit stdout.

phase(){ log "phase: $1"; }

# write_secrets_file: writes /root/ops-secrets/<alias>.env (mode 600) for real;
# under DRY_RUN prints only a redacted placeholder (never the private key).
write_secrets_file(){
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "RUN: write /root/ops-secrets/$ALIAS.env (mode 600, secrets redacted)"
    return 0
  fi
  umask 077; mkdir -p /root/ops-secrets
  cat > "/root/ops-secrets/$ALIAS.env" <<EOF
ALIAS=$ALIAS
DOMAIN=$DOMAIN
UUID=$UUID
REALITY_PRIVATE=$PRIV
REALITY_PUBLIC=$PUB
SHORT_ID=$SID
WEB_PATH=$WEBPATH
BASIC_AUTH=$BASIC
EOF
}

deploy_system(){
  phase system
  run sysctl -w net.core.default_qdisc=fq
  run sysctl -w net.ipv4.tcp_congestion_control=bbr
  run bash -c 'command -v nginx >/dev/null || (yum -y install nginx firewalld socat sqlite httpd-tools || apt-get -y install nginx firewalld socat sqlite apache2-utils)'
}
deploy_install(){
  phase install
  run bash -c 'command -v x-ui >/dev/null || bash <(curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) </dev/null'
}
deploy_configure(){
  phase configure
  read -r PRIV PUB <<<"$(gen_reality_keys)"
  UUID="$(gen_uuid)"; SID="$(gen_subid)"; WEBPATH="$(gen_path)"; BASIC="$(gen_basic_auth opsadmin)"
  run bash -c "umask 077; mkdir -p /root/ops-secrets /usr/local/x-ui/bin"
  render_xray_config "$UUID" "$PRIV" "$SID" | run tee /usr/local/x-ui/bin/config.json >/dev/null
  run x-ui restart
}
deploy_cert(){
  [ -n "$DOMAIN" ] || { log "phase: cert (skipped, no domain)"; return 0; }
  phase cert
  run bash -c "mkdir -p /root/cert/$DOMAIN"
  run bash -c "command -v ~/.acme.sh/acme.sh >/dev/null || curl -fsSL https://get.acme.sh | sh -s email=ops@$DOMAIN"
  run ~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --httpport 80
  run ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --key-file "/root/cert/$DOMAIN/privkey.pem" --fullchain-file "/root/cert/$DOMAIN/fullchain.pem"
}
deploy_firewall(){
  phase firewall
  run firewall-cmd --permanent --add-port=443/tcp
  run firewall-cmd --permanent --add-service=ssh
  run firewall-cmd --permanent --add-service=http
  run firewall-cmd --reload
}
deploy_emit(){
  phase emit
  local link sub host
  host="${DOMAIN:-$(self_ip)}"
  link="$(build_vless_link "$UUID" "$host" "$PUB" "$SID")"
  sub="$(build_sub_url "$DOMAIN" "$WEBPATH")"
  write_secrets_file
  echo "面板：默认仅本机(127.0.0.1:35179)，SSH 隧道访问；需要时 panel-open"
  [ -n "$sub" ] && echo "订阅：$sub"
  echo "VLESS：$link"
}

deploy_run(){
  preflight_gate "$DOMAIN" 80 443 || return 1
  deploy_system; deploy_install; deploy_configure; deploy_cert; deploy_firewall
  cmd_verify || log "verify reported FAIL"
  deploy_emit
}
cmd_deploy(){ deploy_run; }
