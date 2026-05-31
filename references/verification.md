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
- credentials and links are recorded only in the sensitive handover material

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
- x-ui is listening locally but the gateway route is missing.
- x-ui links were copied from the wrong host or tunnel.
- Service is healthy locally but blocked publicly.
- Browser or client cached an old endpoint.

When failures repeat, preserve the exact command and output in the runbook.
