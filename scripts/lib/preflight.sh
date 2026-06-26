#!/usr/bin/env bash
# Preflight gate. Pure orchestration; dns_resolve/self_ip/tcp_open are overridable.

dns_resolve(){ dig +short "$1" A | tail -n1; }
self_ip(){ curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'; }
tcp_open(){ nc -z -G 5 "$1" "$2" >/dev/null 2>&1; }   # tcp_open <ip> <port>

# preflight_gate <domain-or-empty> <port>...
# returns 0 if ready; otherwise prints a checklist to stderr and returns 1.
preflight_gate(){
  local domain="$1"; shift
  local ports="$*" ip ready=0 lines=""
  ip="$(self_ip)"
  if [ -n "$domain" ]; then
    local resolved; resolved="$(dns_resolve "$domain")"
    if [ "$resolved" != "$ip" ]; then
      ready=1
      lines="${lines}- 在 DNS 服务商添加/修正 A 记录： ${domain}  A  ${ip}（当前解析=${resolved:-无}）\n"
    fi
  fi
  local p
  for p in $ports; do
    if ! tcp_open "$ip" "$p"; then
      ready=1
      lines="${lines}- 在云防火墙（如腾讯轻量控制台）放行 TCP 端口 ${p}\n"
    fi
  done
  if [ "$ready" != "0" ]; then
    printf '[preflight] 还差以下人工云操作，做完后重跑 deploy:\n' >&2
    printf '%b' "$lines" >&2
    return 1
  fi
  return 0
}
