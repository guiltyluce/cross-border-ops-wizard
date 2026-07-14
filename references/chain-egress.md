# Chained Proxy Egress Through 3x-ui

Use this module when a phone, browser, or automation client must enter through
an existing VLESS/Reality VPS and leave through a purchased static or
residential proxy:

```text
client -> VLESS/Reality VPS -> client-specific Xray outbound -> purchased exit
```

The acceptance target is persistence and observed egress, not an API success
message or a temporary hot-loaded route.

## 1. Private Inputs

Keep panel and proxy credentials in mode-0600 env files outside the repository.
The panel env supports either `XUI_BASE_URL` or an SSH-tunnel configuration:

```text
XUI_USER=<secret>
XUI_PASS=<secret>
XUI_SCHEME=http
XUI_PORT=<panel-port>
XUI_WEB_BASE_PATH=<random-panel-path>
XUI_SSH_ALIAS=<ssh-config-alias>
XUI_RUNTIME_CONFIG=/usr/local/x-ui/bin/config.json
XUI_DB_PATH=/etc/x-ui/x-ui.db
```

Store one or more proxy tuples in a separate env file. Prefix each tuple so a
single file can hold several purchased exits:

```text
IPNEW_PROTOCOL=socks5
IPNEW_HOST=<provider-gateway>
IPNEW_PORT=<gateway-port>
IPNEW_USER=<secret>
IPNEW_PASS=<secret>
IPNEW_EXIT_IP=<expected-public-ip>
```

Never put these files, generated links, panel paths, or real purchased IPs in a
public repository.

## 2. Preflight

Before changing 3x-ui:

1. Back up the panel database and verify the backup can be read.
2. Test the purchased proxy from the VPS itself.
3. Test every protocol the provider claims to support; SOCKS5 and HTTP may
   behave differently even with the same credentials.
4. Require the observed public IP to equal the purchased exit IP.
5. Record the provider gateway separately from the observed exit.
6. Confirm the intended VLESS inbound ID, client name, and outbound tag.

Do not continue from a local-laptop-only proxy test. Providers may allow their
gateway from the VPS while rejecting the operator's current network, or the
reverse.

## 3. 3x-ui 3.x Persistence Contract

Modern 3x-ui stores clients as first-class records. Use the current client API:

```text
POST /panel/api/clients/add
POST /panel/api/clients/:email/attach
GET  /panel/api/clients/get/:email
GET  /panel/api/clients/links/:email
```

The Xray template endpoint has a different body contract:

```text
POST /panel/api/xray/update
Content-Type: application/x-www-form-urlencoded
xraySetting=<complete-json-template>
outboundTestUrl=<probe-url>
```

Sending JSON to this endpoint is not equivalent. Preserve all unrelated
outbounds and routing rules, replace only the target outbound/rule, and keep
private-address blocking rules ahead of the client-specific route.

After saving, call the force restart endpoint:

```text
POST /panel/api/server/restartXrayService
```

Then read the persisted template, client attachment, and generated runtime
config. A hot apply that works before restart is not a persistence result.

## 4. Deterministic Tool

Preview without writes:

```bash
python3 scripts/xui_chain_egress.py chain-upsert \
  --xui-env ~/.config/vps-ops/node-x-ui.env \
  --ssh-alias managed-node \
  --proxy-env ~/.config/vps-ops/proxy-chains.env \
  --proxy-prefix IPNEW \
  --inbound-id 1 \
  --client-email phone-new \
  --outbound-tag phone_exit_new \
  --output ~/.config/vps-ops/phone-new-delivery.json \
  --dry-run
```

Apply and require a full end-to-end exit check:

```bash
python3 scripts/xui_chain_egress.py chain-upsert \
  --xui-env ~/.config/vps-ops/node-x-ui.env \
  --ssh-alias managed-node \
  --proxy-env ~/.config/vps-ops/proxy-chains.env \
  --proxy-prefix IPNEW \
  --inbound-id 1 \
  --client-email phone-new \
  --outbound-tag phone_exit_new \
  --public-host node.example.test \
  --expected-exit-ip "$EXPECTED_EXIT_IP" \
  --xray-bin ~/.local/bin/xray \
  --output ~/.config/vps-ops/phone-new-delivery.json
```

The tool is idempotent for the same client email and outbound tag. It creates a
remote database backup when `XUI_SSH_ALIAS` exists, writes delivery material
mode `0600`, never prints links, and fails unless post-restart readback passes.
Use `--allow-api-only` only when SSH runtime readback is genuinely unavailable;
record that downgrade as an unresolved verification gap.

## 5. Browser Sidecar

Some fingerprint browsers cannot reach the provider gateway directly, or their
proxy manager cannot test a loopback address. Render a local SOCKS endpoint
from the verified VLESS link:

```bash
python3 scripts/xui_chain_egress.py render-sidecar \
  --link-file ~/.config/vps-ops/phone-new-links.txt \
  --listen-port 19123 \
  --output ~/.config/vps-ops/phone-new-sidecar.json \
  --launchd-output ~/Library/LaunchAgents/com.example.phone-new.plist \
  --label com.example.phone-new \
  --xray-bin ~/.local/bin/xray
```

Load the generated service only after checking that the selected port is free.
The browser should use `socks5://127.0.0.1:<port>`. The browser manager's
loopback test is not authoritative; open the real environment and verify its
public IP from inside the browser.

## 6. Acceptance Harness

All of these must pass:

```text
[ ] proxy authentication from the VPS returns expected_exit_ip
[ ] client record exists and is attached to the intended inbound
[ ] persisted template contains the target outbound and routing rule
[ ] force restart succeeds
[ ] generated runtime config still contains client, outbound, and rule
[ ] official client-link endpoint returns a usable VLESS link
[ ] end-to-end VLESS request returns expected_exit_ip
[ ] fingerprint browser opened with that route returns expected_exit_ip
[ ] credentials and links exist only in approved mode-0600 storage
[ ] asset inventory write is followed by a readback
```

## 7. Asset Record

Keep non-secret fields in the operational inventory or Base table:

- provider and product type
- expected and observed exit IP
- country, city, timezone, ASN, and quality rating
- first-hop VPS alias
- Xray outbound tag and VLESS client email
- fingerprint-browser name and environment name
- credential index, never the credential value
- replacement relationship and renewal date
- last verification time and actual-exit acceptance flag

For Base or other remote inventory writes, run a dry-run where supported, then
perform the write and read the same record back before reporting completion.
