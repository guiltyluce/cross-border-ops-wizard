#!/usr/bin/env python3
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "xui_chain_egress.py"
SPEC = importlib.util.spec_from_file_location("xui_chain_egress", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class TemplateMergeTest(unittest.TestCase):
    def test_merge_is_idempotent_and_preserves_unrelated_config(self):
        template = {
            "outbounds": [
                {"tag": "direct", "protocol": "freedom", "settings": {}},
                {"tag": "egress-us", "protocol": "freedom", "settings": {}},
            ],
            "routing": {
                "domainStrategy": "AsIs",
                "rules": [
                    {"type": "field", "ip": ["geoip:private"], "outboundTag": "blocked"},
                    {"type": "field", "user": ["phone-us"], "outboundTag": "egress-us"},
                ],
            },
        }
        proxy = {
            "protocol": "socks5",
            "host": "proxy.example.test",
            "port": 1080,
            "username": "user",
            "password": "pass",
        }

        once = MODULE.merge_chain_egress(template, proxy, "phone-us", "egress-us")
        twice = MODULE.merge_chain_egress(once, proxy, "phone-us", "egress-us")

        self.assertEqual(once, twice)
        self.assertEqual("direct", twice["outbounds"][0]["tag"])
        self.assertEqual(1, sum(o.get("tag") == "egress-us" for o in twice["outbounds"]))
        self.assertEqual(1, sum(r.get("outboundTag") == "egress-us" for r in twice["routing"]["rules"]))
        self.assertEqual("geoip:private", twice["routing"]["rules"][0]["ip"][0])


class XuiApiContractTest(unittest.TestCase):
    def setUp(self):
        self.client = MODULE.XUIClient.__new__(MODULE.XUIClient)
        self.calls = []

        def post_form(path, data):
            self.calls.append(("form", path, data))
            return {"success": True}

        def post_json(path, data):
            self.calls.append(("json", path, data))
            return {"success": True}

        self.client.post_form = post_form
        self.client.post_json = post_json

    def test_template_update_uses_form_endpoint(self):
        self.client.update_xray_template({"outbounds": []}, "https://example.test/204")

        kind, path, body = self.calls[0]
        self.assertEqual("form", kind)
        self.assertEqual("/panel/api/xray/update", path)
        self.assertEqual({"outbounds": []}, json.loads(body["xraySetting"]))
        self.assertEqual("https://example.test/204", body["outboundTestUrl"])

    def test_client_create_and_force_restart_use_3x_ui_3x_paths(self):
        self.client.create_client("phone-us", 7)
        self.client.force_restart_xray()

        self.assertEqual("/panel/api/clients/add", self.calls[0][1])
        self.assertEqual([7], self.calls[0][2]["inboundIds"])
        self.assertEqual("/panel/api/server/restartXrayService", self.calls[1][1])


class SidecarTest(unittest.TestCase):
    def test_loopback_share_link_requires_public_host_rewrite(self):
        link = (
            "vless://00000000-0000-4000-8000-000000000001@localhost:443"
            "?security=reality&type=tcp#phone-us"
        )

        self.assertTrue(MODULE.vless_link_uses_loopback(link))
        rewritten = MODULE.rewrite_vless_host(link, "node.example.test")
        self.assertFalse(MODULE.vless_link_uses_loopback(rewritten))
        self.assertIn("@node.example.test:443", rewritten)

    def test_vless_reality_link_renders_local_socks_sidecar(self):
        link = (
            "vless://00000000-0000-4000-8000-000000000001@node.example.test:443"
            "?encryption=none&flow=xtls-rprx-vision&security=reality"
            "&sni=www.example.test&fp=chrome&pbk=public-key&sid=abcd&type=tcp"
            "#phone-us"
        )

        config = MODULE.sidecar_config_from_vless(link, 19123)

        self.assertEqual("127.0.0.1", config["inbounds"][0]["listen"])
        self.assertEqual(19123, config["inbounds"][0]["port"])
        self.assertEqual("00000000-0000-4000-8000-000000000001", config["outbounds"][0]["settings"]["vnext"][0]["users"][0]["id"])
        reality = config["outbounds"][0]["streamSettings"]["realitySettings"]
        self.assertEqual("public-key", reality["publicKey"])
        self.assertEqual("abcd", reality["shortId"])

    def test_sensitive_writer_uses_owner_only_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "delivery.json"
            MODULE.write_sensitive(path, {"links": ["vless://secret"]})

            self.assertEqual(0o600, path.stat().st_mode & 0o777)
            self.assertEqual({"links": ["vless://secret"]}, json.loads(path.read_text()))


if __name__ == "__main__":
    unittest.main()
