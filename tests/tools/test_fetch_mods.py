import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
from unittest.mock import patch


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = importlib.util.spec_from_file_location("fetch_mods", os.path.join(ROOT, "tools", "fetch_mods.py"))
fetch_mods = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fetch_mods)


def release(name, version="1.0", date="2026-01-01", dependencies=None, fv="2.0"):
    return {"version": version, "released_at": date, "file_name": name + "_" + version + ".zip",
            "sha1": "0" * 40, "download_url": "/download/" + name,
            "info_json": {"factorio_version": fv, "dependencies": dependencies or []}}


class FetchAdhocTests(unittest.TestCase):
    def test_plan_takes_hard_deps_only(self):
        data = {"A": {"releases": [release("A", dependencies=["base", "B >= 1.0", "? C", "(?) D", "! E", "~ F"])]},
                "B": {"releases": [release("B")]}, "F": {"releases": [release("F")]}}
        with patch.object(fetch_mods, "api", side_effect=lambda n: data[n]):
            self.assertEqual(set(fetch_mods.resolve("2.0", ["A"])), {"A", "B", "F"})

    def test_plan_takes_newest_release_for_version(self):
        releases = [release("A", "2.0", "2026-01-01"), release("A", "2.0", "2026-02-01"),
                    release("A", "2.1", "2026-03-01", fv="2.1")]
        with patch.object(fetch_mods, "api", return_value={"releases": releases}):
            self.assertEqual(fetch_mods.resolve("2.0", ["A"])["A"]["file"], "A_2.0.zip")
            self.assertEqual(fetch_mods.newest("A", "2.0")["released_at"], "2026-02-01")

    def test_plan_skips_builtin_mods(self):
        data = {"A": {"releases": [release("A", dependencies=["space-age", "quality"])]}}
        with patch.object(fetch_mods, "api", side_effect=lambda n: data[n]):
            self.assertEqual(set(fetch_mods.resolve("2.0", ["A"])), {"A"})

    def test_download_refuses_wrong_sha1(self):
        entry = {"file": "bad.zip", "sha1": "0" * 40, "url": "/download/bad"}
        with tempfile.TemporaryDirectory() as d:
            with patch("urllib.request.urlopen", return_value=_Response(b"wrong")):
                with self.assertRaises(SystemExit):
                    fetch_mods.download(entry, d, "user", "token")
            self.assertFalse(os.path.exists(os.path.join(d, "bad.zip")))
            self.assertFalse(os.path.exists(os.path.join(d, "bad.zip.part")))

    def test_download_keeps_good_file(self):
        body = b"valid payload"
        entry = {"file": "good.zip", "sha1": hashlib.sha1(body).hexdigest(), "url": "/download/good"}
        response = _Response(body)
        with tempfile.TemporaryDirectory() as d, patch("urllib.request.urlopen", return_value=response) as urlopen:
            path = fetch_mods.download(entry, d, "user", "token")
            self.assertEqual(open(path, "rb").read(), body)
        request = urlopen.call_args.args[0]
        self.assertIn("username=user", request.full_url)
        self.assertIn("token=token", request.full_url)
        self.assertEqual(request.get_header("User-agent"), "sushi-packer-fetch/1")


class _Response:
    def __init__(self, body):
        self.body = body
        self.pos = 0

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, size):
        part, self.body = self.body[:size], self.body[size:]
        return part


if __name__ == "__main__":
    unittest.main()
