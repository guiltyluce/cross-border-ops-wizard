# Fingerprint Browser Egress Onboarding

Use this module after purchasing a dedicated residential or static proxy and
before assigning accounts to a browser profile. The acceptance target is not
"the proxy test passed". It is:

```text
purchased proxy -> global proxy inventory -> browser profile association
-> in-browser exit verification -> maintainable asset record
```

## 1. Intake And Safety

Collect the proxy as a controlled tuple:

```text
asset_alias=<country-or-purpose>-<short-id>
provider=<provider-name>
protocol=socks5|http|https
host=<provider-hostname-or-ip>
port=<port>
username=<secret>
password=<secret>
expected_exit_ip=<public-ip>
expected_country=<country>
expected_city=<city-or-unknown>
expires_at=<timestamp-or-permanent>
intended_apps=<browser-or-service-list>
```

Keep credentials in a local secret store or the browser application's secure
proxy store. Never put real proxy credentials, private node links, account
cookies, or purchased IP details in this repository.

Before changing a browser profile:

1. Confirm the intended proxy asset and profile name.
2. Preserve existing profiles and sessions; do not overwrite unrelated ones.
3. Test TCP reachability and authenticated proxy access through the actual
   protocol.
4. Compare at least two public IP echo sources when results disagree.
5. Separate "proxy endpoint" from "observed exit IP". They may be different.

## 2. DNS And Multi-A Endpoints

A provider hostname may resolve to several gateway IPs. One unhealthy A record
can make a valid proxy look intermittent.

- Resolve all A records and test each gateway with the same credentials.
- Prefer the provider hostname when every gateway works.
- If only some gateways work, temporarily pin a verified gateway IP and record
  the hostname, tested IP, date, and reason in the private runbook.
- Recheck the hostname later. A pinned gateway is an operational workaround,
  not a permanent assumption.
- Do not confuse the gateway IP with the purchased exit IP.

## 3. Global-First Configuration

Always add and test the proxy in the application's global proxy inventory
before creating or editing a browser profile.

This order is important:

1. Open the global proxy/IP inventory.
2. Add protocol, host, port, username, and password.
3. Run the application's proxy test and confirm country/city plus observed IP.
4. Save the proxy with a stable alias.
5. Create or edit the browser profile.
6. Select the saved global proxy record.
7. Save and reopen the profile.
8. Verify the global inventory shows the profile association.

Do not treat an inline proxy entered during profile creation as a reusable
global proxy. Some products allow the profile to work while leaving the global
proxy inventory empty. That state is usable but incomplete and harder to audit.

## 4. Profile Naming And Fingerprint Alignment

Use a stable name that identifies the exit without exposing credentials:

```text
<exit-short-id>-<country>-full-exit
```

Examples should use documentation-only addresses and generic aliases, never
real purchased IPs.

Align the profile with the observed exit:

- timezone: match the exit region
- language/locale: match the intended account context
- geolocation: derive from the exit or set consistently
- OS and browser kernel: keep stable after account creation
- WebRTC: prevent local-address leakage according to the product's supported mode
- DNS: ensure lookups follow the intended proxy path

Do not rotate OS, timezone, language, and exit country casually on a profile
that already owns a long-lived account session.

## 5. RoxyBrowser

1. Go to `代理 IP`, not only the create-window drawer.
2. Choose `添加`, enter the proxy tuple, and run the connection test.
3. Confirm the observed exit IP and location, then save the global proxy.
4. Create or edit the target window.
5. In `代理 IP`, choose `选择` and select the saved global record.
6. Save the window and open it.
7. On the RoxyChrome dashboard, confirm window ID/name, timezone, location, and
   `IP:` all match the intended asset.
8. Return to `代理 IP` and confirm `已关联窗口` contains the target window ID.

Known pitfall: adding a proxy from the window-creation flow can bind an inline
proxy to the window without adding it to the global proxy list. Repair it by
adding the proxy globally, editing the existing window, selecting the global
record, saving, reopening, and verifying the association.

## 6. AdsPower

1. Add the proxy to AdsPower's reusable proxy inventory when the current
   edition exposes that feature.
2. Test the proxy and confirm the observed exit, not only endpoint reachability.
3. Create or edit the environment and select the saved proxy.
4. Keep OS, User-Agent, timezone, language, WebRTC, and geolocation consistent
   with the intended account context.
5. Open the environment and verify the actual public IP from inside the profile.
6. Return to environment management and confirm the proxy/IP field is populated.

If the edition only supports per-environment proxy input, record that limitation
in the private runbook and use the same naming and acceptance checks.

## 7. Acceptance Harness

Capture fresh evidence for every onboarding or repair:

```text
[ ] global proxy inventory contains the asset
[ ] application proxy test returns the expected exit and region
[ ] target profile selects the global proxy record
[ ] profile opens successfully
[ ] in-browser dashboard or IP echo returns expected_exit_ip
[ ] timezone and geolocation match the intended region
[ ] global inventory shows the target profile association
[ ] no credentials appear in public logs, screenshots, docs, or git
```

When a result is wrong, diagnose in this order:

1. provider gateway reachability and authentication
2. hostname A-record health
3. proxy protocol mismatch
4. inline proxy versus global proxy association
5. local system proxy, Clash/Mihomo, or chain-routing interference
6. browser DNS/WebRTC leakage
7. stale profile state or cached dashboard result

Do not declare completion from a control-panel test alone. Completion requires
a fresh readback from inside the opened browser profile and a global-association
readback from the fingerprint browser application.
