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
  # 幂等：已部署过则复用既有 secrets，避免重生密钥使客户端订阅失效
  if [ -f "/root/ops-secrets/$ALIAS.env" ]; then
    log "configure: 复用已有 secrets（幂等重跑）"
    . "/root/ops-secrets/$ALIAS.env"
    PRIV="$REALITY_PRIVATE"; PUB="$REALITY_PUBLIC"; SID="$SHORT_ID"; WEBPATH="$WEB_PATH"; BASIC="$BASIC_AUTH"
  else
    read -r PRIV PUB <<<"$(gen_reality_keys)"
    UUID="$(gen_uuid)"; SID="$(gen_subid)"; WEBPATH="$(gen_path)"; BASIC="$(gen_basic_auth opsadmin)"
  fi
  run bash -c "umask 077; mkdir -p /root/ops-secrets /usr/local/x-ui/bin /etc/nginx"
  render_xray_config "$UUID" "$PRIV" "$SID" | run tee /usr/local/x-ui/bin/config.json >/dev/null
  # 后台仅绑本机（端口/flag 因 3x-ui 版本而异，Task 12 真机确认具体 flag）
  run x-ui setting -port "$PANEL_PORT" -listenIP 127.0.0.1
  # 写 nginx basic-auth 文件，供 panel-open 时网关使用（密钥经 stdin，不入命令行/不入 stdout）
  printf '%s\n' "$BASIC" | run tee /etc/nginx/ops.htpasswd >/dev/null
  run x-ui restart
}
deploy_cert(){
  [ -n "$DOMAIN" ] || { log "phase: cert (skipped, no domain)"; return 0; }
  phase cert
  run bash -c "mkdir -p /root/cert/$DOMAIN"
  run bash -c "command -v ~/.acme.sh/acme.sh >/dev/null || curl -fsSL https://get.acme.sh | sh -s email=ops@$DOMAIN"
  # 幂等：已有证书则跳过签发，避免 acme --issue 在未到期时以非0退出中断 set -e
  if [ ! -f "/root/cert/$DOMAIN/fullchain.pem" ]; then
    run systemctl stop nginx || true   # 释放 80 端口给 standalone HTTP-01
    run ~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --httpport 80
    run systemctl start nginx || true
    run ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
      --key-file "/root/cert/$DOMAIN/privkey.pem" --fullchain-file "/root/cert/$DOMAIN/fullchain.pem"
  else
    log "cert: 已存在，跳过签发（幂等）"
  fi
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
  deploy_system; deploy_install; deploy_configure; deploy_firewall; deploy_cert
  cmd_verify || log "verify reported FAIL"
  deploy_emit
}
cmd_deploy(){ deploy_run; }
