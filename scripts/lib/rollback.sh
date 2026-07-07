#!/usr/bin/env bash
# Tear down what deploy created.
cmd_rollback(){
  run x-ui stop || true
  run rm -f /etc/nginx/conf.d/ops-gateway.conf
  run firewall-cmd --permanent --remove-port=443/tcp || true
  run firewall-cmd --permanent --remove-port=35178/tcp || true
  run firewall-cmd --reload || true
  run rm -f "/root/ops-secrets/$ALIAS.env"
  echo "已回滚 $ALIAS（x-ui 二进制与系统包保留，避免误删共享依赖）"
}
