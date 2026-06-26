#!/usr/bin/env bash
# Acceptance checks + aggregation.

# verify_summarize "name:1" "name:0" ...  -> prints table, returns 0 if all 1.
verify_summarize(){
  local item name ok all=0
  for item in "$@"; do
    name="${item%%:*}"; ok="${item##*:}"
    if [ "$ok" = "1" ]; then printf '  %s: %s\n' "$name" "OK"; else printf '  %s: %s\n' "$name" "FAIL"; all=1; fi
  done
  if [ "$all" = "0" ]; then echo "ALL PASS"; return 0; else echo "RESULT: FAIL"; return 1; fi
}

# Live checks (used by cmd_verify on a real host).
check_services(){ systemctl is-active --quiet x-ui nginx firewalld sshd && echo 1 || echo 0; }
check_reality443(){ ss -ltn '( sport = :443 )' | grep -q ':443' && echo 1 || echo 0; }
check_panel_local(){ ss -ltn | grep -q '127.0.0.1:35179' && echo 1 || echo 0; }
check_bbr(){ [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ] && echo 1 || echo 0; }

cmd_verify(){
  verify_summarize \
    "services:$(check_services)" \
    "reality443:$(check_reality443)" \
    "panel_local:$(check_panel_local)" \
    "bbr:$(check_bbr)"
}
