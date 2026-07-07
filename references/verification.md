# Verification And Troubleshooting

## Service Checks

```bash
ssh <alias> 'hostname; uptime'
ssh <alias> 'systemctl --failed --no-pager'
ssh <alias> 'ss -ltnp'
ssh <alias> 'journalctl -n 120 --no-pager'
```

When x-ui is part of the delivery scope, also check its service state and logs
according to the installed distribution:

```bash
ssh <alias> 'systemctl status x-ui --no-pager || systemctl status xui --no-pager || true'
ssh <alias> 'journalctl -u x-ui -n 80 --no-pager || journalctl -u xui -n 80 --no-pager || true'
```

## DNS Checks

```bash
dig +short <domain>
dig @1.1.1.1 +short <domain>
dig @8.8.8.8 +short <domain>
```

All resolvers should point to the intended public IP before certificate or
gateway debugging continues.

## HTTP/TLS Checks

```bash
curl --noproxy '*' -4sS -o /dev/null -w 'health=%{http_code} ip=%{remote_ip}\n' \
  http://<domain>/healthz
curl --noproxy '*' -4sS -o /dev/null -w 'gateway=%{http_code}\n' \
  https://<domain>/
echo | openssl s_client -connect <domain>:443 -servername <domain> 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates
```

## Port Checks

```bash
for p in 22 80 443; do
  printf '%s ' "$p"
  nc -vz -G 5 <public_ip> "$p" 2>&1 | tail -n 1
done
```

Expected results depend on the agreed design. Public ports should be reachable;
private/admin ports should fail from the public internet unless explicitly
approved.

For x-ui, verify:

- panel is reachable only through the intended domain/path or protected route
- administrator login works
- generated team links use the public domain, not `127.0.0.1` or a temporary tunnel
- generated VLESS links include the validated Reality SNI, default `www.apple.com`
- credentials and links are recorded only in the sensitive handover material

## Reality / Client Acceptance

Check generated links:

```text
@<domain-or-ip>:443
security=reality
flow=xtls-rprx-vision
sni=<validated_reality_sni>
```

For new nodes, the default target is `www.apple.com`. If older material still
uses `www.microsoft.com`, treat it as a compatibility risk and verify the
server-side Reality target before redistributing links.

When changing Reality target/SNI, verify persistence:

- server config has matching `dest` and `serverNames`
- generated VLESS links have matching `sni`
- desktop client disk config matches runtime config after restart
- mobile clients or subscriptions have been re-imported

## Speed Checks

Separate directions:

1. Node downloading from public mirrors.
2. Operator downloading data from the node.
3. Business application path through the intended gateway.

Do not treat a single client-side speed number as the whole diagnosis.

## Route / Packet-Loss Diagnosis (when users report "slow download")

Most "slow" reports on a healthy node are a path problem on the VPS-to-client
segment, not the server. Localize by elimination, in order:

1. Prove the server side is healthy (fast egress, not a bandwidth cap):

```bash
ssh <alias> 'sysctl -n net.ipv4.tcp_congestion_control net.core.default_qdisc'   # expect bbr / fq
ssh <alias> 'curl -4 -o /dev/null --max-time 20 -w "speed=%{speed_download}B/s\n" \
  https://speedtest.tokyo2.linode.com/100MB-tokyo2.bin'                          # use a region-near IPv4 mirror; a far mirror (e.g. EU) is not a fair test
```

2. Measure the VPS-to-China-ISP path quality (loss + route). Run during the
   user's actual peak hours, since congestion is time-of-day dependent:

```bash
ssh <alias> 'for ip in 202.96.209.133 119.29.29.29; do \
  printf "%s " "$ip"; ping -c 20 -i 0.2 -W 2 -q "$ip" | grep -E "packet loss|rtt"; done'
ssh <alias> 'traceroute -n -w 2 -q 1 -m 15 202.96.209.133'   # 202.97.x = China Telecom 163 (congested); CN2/优化线路 routes differ
```

3. Read the client (v2rayN/xray) log. Key signals and meaning:

- `dial tcp <node-ip>:443: i/o timeout` (intermittent) = SYN loss on the path
- `dns: exchange failed ... context deadline exceeded / EOF` = DNS over a lossy
  tunnel; symptom of loss, not a DNS config bug
- `当前延迟: -1 ms，none` = node probe timed out under loss; traffic may still
  flow. `-1ms` alone does not mean the node is down.

Interpretation: high loss (e.g. 10-20%) on a generic Tencent/100MB 163 route at
peak hour collapses TCP/Reality throughput and times out DNS. Server tuning
(BBR is already the best lever) cannot fix the line. Real fixes: try a
better-peered landing IP, or add a CN2/IPLC relay in front
(`client -> relay -> node`). Confirm the diagnosis cheaply by retesting off-peak.

## Common Failures

- DNS has not propagated.
- Cloud firewall and system firewall disagree.
- Certificate was issued for a different domain.
- Gateway path or authentication is wrong.
- x-ui is listening locally but the gateway route is missing.
- x-ui links were copied from the wrong host or tunnel.
- Service is healthy locally but blocked publicly.
- Browser or client cached an old endpoint.
- Local Clash/Mihomo fake-ip resolves the node domain to `198.18.0.0/16`.
- Reality target/SNI mismatch causes immediate VLESS EOF even while ports are open.
- Client config was hot-reloaded but not written to disk, then reverted after restart.

## Incident Triage Harness

When a node appears fully down, separate the layers before reinstalling:

1. Services/listeners:

```bash
ssh <alias> 'systemctl is-active x-ui nginx firewalld sshd; ss -ltnp | grep -E ":(443|35178|35179|2096)"'
ssh <alias> 'journalctl -u x-ui --since "-3 hours" --no-pager | tail -n 160'
```

2. Direct public path, bypassing local proxy/fake-ip:

```bash
curl --noproxy '*' -4sS -o /dev/null -w 'health=%{http_code} ip=%{remote_ip}\n' \
  http://<domain>/healthz
```

3. Local DNS/proxy artifacts:

```bash
dig +short <domain>
```

If the local result is in `198.18.0.0/16`, re-check from the VPS or a direct
path before changing the server.

4. Reality EOF:

```bash
ssh <alias> 'journalctl -u x-ui -n 300 --no-pager | grep -E "REALITY|invalid connection|hs\\.c\\.conn|EOF" || true'
```

If every client gets immediate EOF while services and ports are healthy, check
Reality target/SNI before regenerating keys or downgrading xray.

When failures repeat, preserve the exact command and output in the runbook.
