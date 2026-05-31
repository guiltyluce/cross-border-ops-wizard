# Verification And Troubleshooting

## Service Checks

```bash
ssh <alias> 'hostname; uptime'
ssh <alias> 'systemctl --failed --no-pager'
ssh <alias> 'ss -ltnp'
ssh <alias> 'journalctl -n 120 --no-pager'
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

## Speed Checks

Separate directions:

1. Node downloading from public mirrors.
2. Operator downloading data from the node.
3. Business application path through the intended gateway.

Do not treat a single client-side speed number as the whole diagnosis.

## Common Failures

- DNS has not propagated.
- Cloud firewall and system firewall disagree.
- Certificate was issued for a different domain.
- Gateway path or authentication is wrong.
- Service is healthy locally but blocked publicly.
- Browser or client cached an old endpoint.

When failures repeat, preserve the exact command and output in the runbook.
