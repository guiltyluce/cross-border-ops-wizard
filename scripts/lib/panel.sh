#!/usr/bin/env bash
# On-demand public admin gateway toggle.

load_node_env(){ . "/root/ops-secrets/$ALIAS.env"; }

cmd_panel_open(){
  [ -n "$DOMAIN" ] || { echo "[error] panel-open 需要 --domain（IP-only 节点请用 SSH 隧道访问后台）" >&2; return 1; }
  load_node_env
  preflight_gate "$DOMAIN" "$GATEWAY_PORT" || return 1
  printf '%s\n' "${BASIC_AUTH:-}" | run tee /etc/nginx/ops.htpasswd >/dev/null
  run chmod 640 /etc/nginx/ops.htpasswd
  render_nginx_gateway "$DOMAIN" "$WEB_PATH" | run tee /etc/nginx/conf.d/ops-gateway.conf >/dev/null
  run firewall-cmd --permanent --add-port=35178/tcp
  run firewall-cmd --reload
  run nginx -s reload
  echo "面板已临时开放： https://$DOMAIN:$GATEWAY_PORT/$WEB_PATH/"
}

cmd_panel_close(){
  run rm -f /etc/nginx/conf.d/ops-gateway.conf
  run firewall-cmd --permanent --remove-port=35178/tcp
  run firewall-cmd --reload
  run nginx -s reload
  echo "面板公网入口已关闭"
}
