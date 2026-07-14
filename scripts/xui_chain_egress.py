#!/usr/bin/env python3
"""Persist a per-client proxy egress in 3x-ui 3.x and render local sidecars.

Credentials are loaded from private env files. The tool never prints proxy
credentials or VLESS URLs; sensitive delivery material is written mode 0600.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import http.cookiejar
import json
import os
import re
import shlex
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterator


DEFAULT_TEST_URL = "https://www.google.com/generate_204"
DEFAULT_RUNTIME_CONFIG = "/usr/local/x-ui/bin/config.json"
DEFAULT_DB_PATH = "/etc/x-ui/x-ui.db"


class OpsError(RuntimeError):
    pass


def load_env(path: str | Path) -> dict[str, str]:
    result: dict[str, str] = {}
    with Path(path).expanduser().open(encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip().strip('"').strip("'")
    return result


def required(env: dict[str, str], *names: str) -> None:
    missing = [name for name in names if not env.get(name)]
    if missing:
        raise OpsError("missing required env keys: " + ", ".join(missing))


def unwrap_json(value: Any) -> Any:
    while isinstance(value, str):
        value = json.loads(value)
    return value


def check_response(response: dict[str, Any], action: str) -> dict[str, Any]:
    if not response.get("success"):
        raise OpsError("%s failed: %s" % (action, response.get("msg", "unknown error")))
    return response


@contextlib.contextmanager
def ssh_tunnel(alias: str, remote_port: int) -> Iterator[int]:
    probe = socket.socket()
    probe.bind(("127.0.0.1", 0))
    local_port = probe.getsockname()[1]
    probe.close()
    process = subprocess.Popen(
        [
            "ssh",
            "-o", "BatchMode=yes",
            "-o", "ExitOnForwardFailure=yes",
            "-N", "-L", "%d:127.0.0.1:%d" % (local_port, remote_port),
            alias,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise OpsError("SSH tunnel exited before becoming ready")
            try:
                with socket.create_connection(("127.0.0.1", local_port), timeout=0.5):
                    break
            except OSError:
                time.sleep(0.2)
        else:
            raise OpsError("SSH tunnel did not become ready")
        yield local_port
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


class XUIClient:
    def __init__(self, base_url: str, username: str, password: str, insecure: bool = False):
        self.base_url = base_url.rstrip("/")
        self.username = username
        self.password = password
        self.csrf_token = ""
        context = ssl._create_unverified_context() if insecure else ssl.create_default_context()
        self.cookies = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookies),
            urllib.request.HTTPSHandler(context=context),
        )

    def _request(self, method: str, path: str, body: bytes | None = None,
                 content_type: str | None = None) -> dict[str, Any]:
        request = urllib.request.Request(self.base_url + path, data=body, method=method)
        if content_type:
            request.add_header("Content-Type", content_type)
        if self.csrf_token:
            request.add_header("X-CSRF-Token", self.csrf_token)
        with self.opener.open(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))

    def get(self, path: str) -> dict[str, Any]:
        return self._request("GET", path)

    def post_form(self, path: str, data: dict[str, Any]) -> dict[str, Any]:
        body = urllib.parse.urlencode(data).encode("utf-8")
        return self._request("POST", path, body, "application/x-www-form-urlencoded")

    def post_json(self, path: str, data: Any) -> dict[str, Any]:
        body = json.dumps(data, separators=(",", ":")).encode("utf-8")
        return self._request("POST", path, body, "application/json")

    def login(self) -> None:
        try:
            self.csrf_token = self.get("/csrf-token").get("obj", "")
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
        response = self.post_form("/login", {
            "username": self.username,
            "password": self.password,
        })
        check_response(response, "login")

    def list_clients(self) -> list[dict[str, Any]]:
        return check_response(self.get("/panel/api/clients/list"), "list clients").get("obj", [])

    def get_client(self, email: str) -> dict[str, Any]:
        path = "/panel/api/clients/get/" + urllib.parse.quote(email, safe="")
        return check_response(self.get(path), "get client").get("obj", {})

    def create_client(self, email: str, inbound_id: int) -> dict[str, Any]:
        return check_response(self.post_json("/panel/api/clients/add", {
            "client": {
                "email": email,
                "enable": True,
                "flow": "xtls-rprx-vision",
                "limitIp": 0,
                "totalGB": 0,
                "expiryTime": 0,
                "tgId": 0,
            },
            "inboundIds": [inbound_id],
        }), "create client")

    def attach_client(self, email: str, inbound_id: int) -> dict[str, Any]:
        path = "/panel/api/clients/%s/attach" % urllib.parse.quote(email, safe="")
        return check_response(self.post_json(path, {"inboundIds": [inbound_id]}), "attach client")

    def xray_envelope(self) -> dict[str, Any]:
        response = check_response(self.post_form("/panel/api/xray/", {}), "get Xray template")
        return unwrap_json(response.get("obj"))

    def update_xray_template(self, template: dict[str, Any], test_url: str = DEFAULT_TEST_URL) -> dict[str, Any]:
        return check_response(self.post_form("/panel/api/xray/update", {
            "xraySetting": json.dumps(template, separators=(",", ":")),
            "outboundTestUrl": test_url or DEFAULT_TEST_URL,
        }), "update Xray template")

    def force_restart_xray(self) -> dict[str, Any]:
        return check_response(self.post_form("/panel/api/server/restartXrayService", {}), "force restart Xray")

    def client_links(self, email: str) -> list[str]:
        path = "/panel/api/clients/links/" + urllib.parse.quote(email, safe="")
        return check_response(self.get(path), "get client links").get("obj", [])


def proxy_from_env(env: dict[str, str], prefix: str) -> dict[str, Any]:
    prefix = prefix.rstrip("_") + "_"
    keys = {name: prefix + name for name in ("HOST", "PORT", "USER", "PASS")}
    missing = [key for name, key in keys.items() if not env.get(key)]
    if missing:
        raise OpsError("missing proxy env keys: " + ", ".join(missing))
    protocol = env.get(prefix + "PROTOCOL", "socks5").lower()
    if protocol not in ("socks", "socks5", "http"):
        raise OpsError("unsupported proxy protocol: %s (expected socks5 or http)" % protocol)
    return {
        "protocol": protocol,
        "host": env[keys["HOST"]],
        "port": int(env[keys["PORT"]]),
        "username": env[keys["USER"]],
        "password": env[keys["PASS"]],
    }


def build_proxy_outbound(proxy: dict[str, Any], outbound_tag: str) -> dict[str, Any]:
    protocol = "socks" if proxy["protocol"] in ("socks", "socks5") else "http"
    return {
        "tag": outbound_tag,
        "protocol": protocol,
        "settings": {
            "servers": [{
                "address": proxy["host"],
                "port": int(proxy["port"]),
                "users": [{"user": proxy["username"], "pass": proxy["password"]}],
            }],
        },
    }


def merge_chain_egress(template: dict[str, Any], proxy: dict[str, Any],
                       client_email: str, outbound_tag: str) -> dict[str, Any]:
    merged = copy.deepcopy(template)
    outbounds = merged.setdefault("outbounds", [])
    merged["outbounds"] = [item for item in outbounds if item.get("tag") != outbound_tag]
    merged["outbounds"].append(build_proxy_outbound(proxy, outbound_tag))

    routing = merged.setdefault("routing", {})
    rules = routing.setdefault("rules", [])
    routing["rules"] = [
        rule for rule in rules
        if rule.get("outboundTag") != outbound_tag
        and client_email not in (rule.get("user") or [])
    ]
    routing["rules"].append({
        "type": "field",
        "user": [client_email],
        "outboundTag": outbound_tag,
    })
    return merged


def ensure_client(client: XUIClient, email: str, inbound_id: int) -> dict[str, Any]:
    rows = {row.get("email"): row for row in client.list_clients()}
    row = rows.get(email)
    if row is None:
        client.create_client(email, inbound_id)
    elif inbound_id not in (row.get("inboundIds") or []):
        client.attach_client(email, inbound_id)
    result = client.get_client(email)
    if inbound_id not in (result.get("inboundIds") or []):
        raise OpsError("client was not attached to inbound after write")
    return result


def template_state(template: dict[str, Any], email: str, outbound_tag: str) -> dict[str, bool]:
    return {
        "outbound": any(item.get("tag") == outbound_tag for item in template.get("outbounds", [])),
        "routing": any(
            rule.get("outboundTag") == outbound_tag and email in (rule.get("user") or [])
            for rule in template.get("routing", {}).get("rules", [])
        ),
    }


def write_sensitive(path: str | Path, value: Any) -> None:
    target = Path(path).expanduser()
    target.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, str):
        content = value
    else:
        content = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
    finally:
        os.chmod(target, 0o600)


def first_vless_link(text: str) -> str:
    match = re.search(r"vless://[^\s]+", text)
    if not match:
        raise OpsError("no VLESS link found")
    return match.group(0)


def rewrite_vless_host(link: str, public_host: str) -> str:
    parsed = urllib.parse.urlsplit(link)
    if parsed.scheme != "vless" or not parsed.username or not parsed.port:
        raise OpsError("invalid VLESS link")
    host = public_host.strip("[]")
    if ":" in host:
        host = "[%s]" % host
    netloc = "%s@%s:%d" % (parsed.username, host, parsed.port)
    return urllib.parse.urlunsplit((parsed.scheme, netloc, parsed.path, parsed.query, parsed.fragment))


def vless_link_uses_loopback(link: str) -> bool:
    if not link.startswith("vless://"):
        return False
    host = (urllib.parse.urlsplit(link).hostname or "").lower()
    return host in ("localhost", "127.0.0.1", "::1")


def sidecar_config_from_vless(link: str, listen_port: int) -> dict[str, Any]:
    parsed = urllib.parse.urlsplit(link)
    query = urllib.parse.parse_qs(parsed.query)
    if parsed.scheme != "vless" or not parsed.username or not parsed.hostname or not parsed.port:
        raise OpsError("invalid VLESS link")

    def one(name: str, default: str = "") -> str:
        return query.get(name, [default])[0]

    user = {
        "id": urllib.parse.unquote(parsed.username),
        "encryption": one("encryption", "none"),
    }
    if one("flow"):
        user["flow"] = one("flow")
    stream: dict[str, Any] = {
        "network": one("type", "tcp"),
        "security": one("security", "none"),
    }
    if stream["security"] == "reality":
        stream["realitySettings"] = {
            "serverName": one("sni"),
            "fingerprint": one("fp", "chrome"),
            "publicKey": one("pbk"),
            "shortId": one("sid"),
            "spiderX": one("spx", "/"),
            "show": False,
        }
    return {
        "log": {"loglevel": "warning"},
        "inbounds": [{
            "tag": "local-socks-sidecar",
            "listen": "127.0.0.1",
            "port": listen_port,
            "protocol": "socks",
            "settings": {"auth": "noauth", "udp": True},
        }],
        "outbounds": [{
            "tag": "managed-vless",
            "protocol": "vless",
            "settings": {"vnext": [{
                "address": parsed.hostname,
                "port": parsed.port,
                "users": [user],
            }]},
            "streamSettings": stream,
        }],
        "routing": {"domainStrategy": "AsIs", "rules": []},
    }


def launchd_plist(label: str, xray_bin: str, config_path: str) -> str:
    import xml.sax.saxutils

    esc = xml.sax.saxutils.escape
    return """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>{label}</string>
  <key>ProgramArguments</key><array>
    <string>{xray}</string><string>run</string><string>-config</string><string>{config}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
""".format(label=esc(label), xray=esc(xray_bin), config=esc(config_path))


def backup_database(env: dict[str, str]) -> str:
    alias = env.get("XUI_SSH_ALIAS", "")
    if not alias:
        return "skipped_no_ssh_alias"
    db_path = env.get("XUI_DB_PATH", DEFAULT_DB_PATH)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    target = "/root/x-ui-backups/x-ui-before-chain-%s.db" % stamp
    command = "install -d -m 700 /root/x-ui-backups && cp %s %s && chmod 600 %s" % (
        shlex.quote(db_path), shlex.quote(target), shlex.quote(target))
    subprocess.run(["ssh", "-o", "BatchMode=yes", alias, command], check=True)
    return target


def verify_runtime_via_ssh(env: dict[str, str], email: str, outbound_tag: str) -> bool:
    alias = env.get("XUI_SSH_ALIAS", "")
    if not alias:
        return False
    runtime_path = env.get("XUI_RUNTIME_CONFIG", DEFAULT_RUNTIME_CONFIG)
    script = r'''import json,sys
d=json.load(open(sys.argv[1]))
email=sys.argv[2]; tag=sys.argv[3]
out={item.get("tag") for item in d.get("outbounds",[])}
routes={item.get("outboundTag") for item in d.get("routing",{}).get("rules",[])}
users=set()
for inbound in d.get("inbounds",[]):
    settings=inbound.get("settings",{})
    if isinstance(settings,str):
        try: settings=json.loads(settings)
        except ValueError: settings={}
    users.update(item.get("email") for item in settings.get("clients",[]))
print(json.dumps({"ok": tag in out and tag in routes and email in users}))
'''
    remote = "python3 - %s %s %s" % tuple(map(shlex.quote, (runtime_path, email, outbound_tag)))
    result = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", alias, remote],
        input=script, text=True, capture_output=True, check=True,
    )
    return bool(json.loads(result.stdout).get("ok"))


def verify_exit(link: str, expected_ip: str, xray_bin: str, curl_bin: str) -> str:
    with tempfile.TemporaryDirectory(prefix="chain-egress-") as tmp:
        probe = socket.socket()
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
        probe.close()
        config_path = Path(tmp) / "sidecar.json"
        write_sensitive(config_path, sidecar_config_from_vless(link, port))
        process = subprocess.Popen(
            [xray_bin, "run", "-config", str(config_path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            for _ in range(40):
                if process.poll() is not None:
                    raise OpsError("temporary Xray sidecar exited")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                        break
                except OSError:
                    time.sleep(0.2)
            output = subprocess.check_output([
                curl_bin, "--silent", "--show-error", "--max-time", "30",
                "--proxy", "socks5h://127.0.0.1:%d" % port,
                "https://api.ipify.org",
            ], text=True).strip()
            if output != expected_ip:
                raise OpsError("end-to-end exit mismatch: expected %s, got %s" % (expected_ip, output))
            return output
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()


@contextlib.contextmanager
def connected_client(env: dict[str, str]) -> Iterator[XUIClient]:
    env = dict(env)
    env.setdefault("XUI_USER", env.get("XUI_ADMIN_USER", ""))
    env.setdefault("XUI_PASS", env.get("XUI_ADMIN_PASS", ""))
    required(env, "XUI_USER", "XUI_PASS")
    insecure = env.get("XUI_INSECURE", "0").lower() in ("1", "true", "yes")
    if env.get("XUI_BASE_URL"):
        client = XUIClient(env["XUI_BASE_URL"], env["XUI_USER"], env["XUI_PASS"], insecure)
        client.login()
        yield client
        return

    required(env, "XUI_PORT", "XUI_WEB_BASE_PATH")
    scheme = env.get("XUI_SCHEME", "http")
    base_path = "/" + env["XUI_WEB_BASE_PATH"].strip("/")
    alias = env.get("XUI_SSH_ALIAS", "")
    if alias:
        with ssh_tunnel(alias, int(env["XUI_PORT"])) as local_port:
            client = XUIClient("%s://127.0.0.1:%d%s" % (scheme, local_port, base_path),
                               env["XUI_USER"], env["XUI_PASS"], insecure)
            client.login()
            yield client
    else:
        required(env, "XUI_HOST")
        client = XUIClient("%s://%s:%s%s" % (scheme, env["XUI_HOST"], env["XUI_PORT"], base_path),
                           env["XUI_USER"], env["XUI_PASS"], insecure)
        client.login()
        yield client


def command_chain_upsert(args: argparse.Namespace) -> int:
    xui_env = load_env(args.xui_env)
    if args.ssh_alias:
        xui_env["XUI_SSH_ALIAS"] = args.ssh_alias
    proxy = proxy_from_env(load_env(args.proxy_env), args.proxy_prefix)
    with connected_client(xui_env) as client:
        envelope = client.xray_envelope()
        template = unwrap_json(envelope["xraySetting"])
        merged = merge_chain_egress(template, proxy, args.client_email, args.outbound_tag)
        before = template_state(template, args.client_email, args.outbound_tag)
        if args.dry_run:
            print(json.dumps({
                "dry_run": True,
                "client_email": args.client_email,
                "inbound_id": args.inbound_id,
                "outbound_tag": args.outbound_tag,
                "existing_state": before,
                "writes": 0,
            }, indent=2))
            return 0

        backup = backup_database(xui_env)
        client_info = ensure_client(client, args.client_email, args.inbound_id)
        client.update_xray_template(merged, envelope.get("outboundTestUrl", DEFAULT_TEST_URL))
        client.force_restart_xray()
        time.sleep(args.restart_wait)

        final_envelope = client.xray_envelope()
        final_template = unwrap_json(final_envelope["xraySetting"])
        state = template_state(final_template, args.client_email, args.outbound_tag)
        final_client = client.get_client(args.client_email)
        if not all(state.values()) or args.inbound_id not in (final_client.get("inboundIds") or []):
            raise OpsError("persisted template/client readback failed after force restart")

        runtime_ok = verify_runtime_via_ssh(xui_env, args.client_email, args.outbound_tag)
        if not runtime_ok and not args.allow_api_only:
            raise OpsError("runtime config readback unavailable or failed; set XUI_SSH_ALIAS or use --allow-api-only")

        links = client.client_links(args.client_email)
        if args.public_host:
            links = [rewrite_vless_host(link, args.public_host) if link.startswith("vless://") else link for link in links]
        if not links:
            raise OpsError("3x-ui returned no client links")
        if any(vless_link_uses_loopback(link) for link in links):
            raise OpsError("generated VLESS link uses loopback; pass --public-host")
        delivery = {
            "client_email": args.client_email,
            "inbound_id": args.inbound_id,
            "outbound_tag": args.outbound_tag,
            "client": client_info.get("client", final_client.get("client", {})),
            "links": links,
        }
        write_sensitive(args.output, delivery)

        exit_result = "not_requested"
        if args.expected_exit_ip:
            vless = next((link for link in links if link.startswith("vless://")), "")
            if not vless:
                raise OpsError("end-to-end verification requires a VLESS link")
            exit_result = verify_exit(vless, args.expected_exit_ip, args.xray_bin, args.curl_bin)

        print(json.dumps({
            "ok": True,
            "client_email": args.client_email,
            "outbound_tag": args.outbound_tag,
            "backup": backup,
            "persisted_readback": state,
            "runtime_readback": "pass" if runtime_ok else "skipped_api_only",
            "link_count": len(links),
            "delivery_file": str(Path(args.output).expanduser()),
            "end_to_end_exit": exit_result,
        }, indent=2))
    return 0


def command_summary(args: argparse.Namespace) -> int:
    env = load_env(args.xui_env)
    if args.ssh_alias:
        env["XUI_SSH_ALIAS"] = args.ssh_alias
    with connected_client(env) as client:
        envelope = client.xray_envelope()
        template = unwrap_json(envelope["xraySetting"])
        print(json.dumps({
            "clients": len(client.list_clients()),
            "outbound_tags": [item.get("tag") for item in template.get("outbounds", [])],
            "routing_rules": len(template.get("routing", {}).get("rules", [])),
        }, indent=2))
    return 0


def command_render_sidecar(args: argparse.Namespace) -> int:
    text = Path(args.link_file).expanduser().read_text(encoding="utf-8")
    link = first_vless_link(text)
    output = Path(args.output).expanduser()
    write_sensitive(output, sidecar_config_from_vless(link, args.listen_port))
    result = {"config": str(output), "listen": "127.0.0.1:%d" % args.listen_port}
    if args.launchd_output:
        plist_path = Path(args.launchd_output).expanduser()
        plist_path.parent.mkdir(parents=True, exist_ok=True)
        plist_path.write_text(launchd_plist(args.label, args.xray_bin, str(output)), encoding="utf-8")
        os.chmod(plist_path, 0o644)
        result["launchd_plist"] = str(plist_path)
    print(json.dumps(result, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    summary = subparsers.add_parser("summary", help="Read a sanitized panel summary")
    summary.add_argument("--xui-env", required=True)
    summary.add_argument("--ssh-alias", default="", help="Override XUI_SSH_ALIAS from the env file")
    summary.set_defaults(func=command_summary)

    chain = subparsers.add_parser("chain-upsert", help="Persist one client-specific proxy egress")
    chain.add_argument("--xui-env", required=True)
    chain.add_argument("--ssh-alias", default="", help="Override XUI_SSH_ALIAS from the env file")
    chain.add_argument("--proxy-env", required=True)
    chain.add_argument("--proxy-prefix", required=True, help="Env prefix such as IPNEW")
    chain.add_argument("--inbound-id", required=True, type=int)
    chain.add_argument("--client-email", required=True)
    chain.add_argument("--outbound-tag", required=True)
    chain.add_argument("--output", required=True, help="Mode-0600 JSON delivery path")
    chain.add_argument("--public-host", default="", help="Rewrite generated VLESS links to this public host")
    chain.add_argument("--expected-exit-ip", default="")
    chain.add_argument("--xray-bin", default="xray")
    chain.add_argument("--curl-bin", default="curl")
    chain.add_argument("--restart-wait", type=float, default=3.0)
    chain.add_argument("--allow-api-only", action="store_true")
    chain.add_argument("--dry-run", action="store_true")
    chain.set_defaults(func=command_chain_upsert)

    sidecar = subparsers.add_parser("render-sidecar", help="Render a local SOCKS sidecar from a VLESS link")
    sidecar.add_argument("--link-file", required=True)
    sidecar.add_argument("--listen-port", required=True, type=int)
    sidecar.add_argument("--output", required=True)
    sidecar.add_argument("--launchd-output", default="")
    sidecar.add_argument("--label", default="com.example.xray-sidecar")
    sidecar.add_argument("--xray-bin", default="xray")
    sidecar.set_defaults(func=command_render_sidecar)
    return parser


def main() -> int:
    try:
        args = build_parser().parse_args()
        return args.func(args)
    except (OpsError, OSError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print("error: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
