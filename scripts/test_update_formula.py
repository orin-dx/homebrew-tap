import base64
import hashlib
import io
import json
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
from update_formula import fetch_bytes, latest_tag, list_tools, load_tool, update

SOURCE_ROOT = Path(__file__).resolve().parents[1]


def archive_for(target, package, version):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w:gz") as tar:
        for name in target["members"]:
            if name == "package/package.json":
                payload = json.dumps({"name": package, "version": version}).encode()
            else:
                payload = b"binary" if name == target["binary"] else b"readme"
            member = tarfile.TarInfo(name)
            member.size = len(payload)
            member.mode = 0o755 if name == target["binary"] else 0o644
            tar.addfile(member, io.BytesIO(payload))
    return stream.getvalue()


class FormulaUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tools").mkdir()
        (self.root / "Formula").mkdir()

    def fixture(self, tool, new_version="0.6.0"):
        config = load_tool(SOURCE_ROOT, tool)
        (self.root / "tools" / f"{tool}.json").write_text(json.dumps(config))
        formula = self.root / config["formula"]
        zero_hash = "0" * 64
        formula.write_text('  version "0.5.0"\n' + "\n".join(
            f'  url "{target["url"].format(version="0.5.0")}"\n  sha256 "{zero_hash}"'
            for target in config["targets"]
        ) + "\n")
        replies = {}
        assets = []
        for target in config["targets"]:
            package = target.get("package", "")
            url = target["url"].format(version=new_version)
            archive = archive_for(target, package, new_version)
            replies[url] = archive
            if tool == "callisto":
                assets.append({
                    "name": target["asset"],
                    "browser_download_url": url,
                    "digest": "sha256:" + hashlib.sha256(archive).hexdigest(),
                })
            else:
                replies[f"https://registry.npmjs.org/{package}/{new_version}"] = json.dumps({
                    "name": package,
                    "version": new_version,
                    "dist": {
                        "tarball": url,
                        "integrity": "sha512-" + base64.b64encode(hashlib.sha512(archive).digest()).decode(),
                    },
                }).encode()
        if tool == "callisto":
            replies[f"https://api.github.com/repos/orin-dx/callisto/releases/tags/callisto%40{new_version}"] = json.dumps({
                "tag_name": f"callisto@{new_version}",
                "draft": False,
                "prerelease": False,
                "assets": assets,
            }).encode()
        return config, formula, replies

    def test_github_release_updates_all_targets(self):
        _, formula, replies = self.fixture("callisto")
        self.assertEqual(update(self.root, "callisto", "callisto@0.6.0", replies.__getitem__), "0.6.0")
        self.assertEqual(formula.read_text().count("0.6.0"), 5)
        self.assertIn('  version "0.6.0"', formula.read_text())
        self.assertNotIn('sha256 "' + "0" * 64, formula.read_text())

    def test_npm_packages_update_all_targets(self):
        _, formula, replies = self.fixture("caliper")
        self.assertEqual(update(self.root, "caliper", "npm/caliper-docgen@0.6.0", replies.__getitem__), "0.6.0")
        self.assertEqual(formula.read_text().count("0.6.0"), 5)
        self.assertIn('  version "0.6.0"', formula.read_text())

    def test_formula_version_must_match_platform_urls(self):
        _, formula, replies = self.fixture("callisto")
        formula.write_text(formula.read_text().replace('version "0.5.0"', 'version "0.4.0"'))
        with self.assertRaisesRegex(ValueError, "version disagrees"):
            update(self.root, "callisto", "callisto@0.6.0", replies.__getitem__)

    def test_tampered_archive_leaves_formula_unchanged(self):
        config, formula, replies = self.fixture("caliper")
        original = formula.read_text()
        target = config["targets"][2]
        replies[target["url"].format(version="0.6.0")] = b"tampered"
        with self.assertRaisesRegex(ValueError, "published digest"):
            update(self.root, "caliper", "npm/caliper-docgen@0.6.0", replies.__getitem__)
        self.assertEqual(formula.read_text(), original)

    def test_download_limit_is_enforced_without_content_length(self):
        response = io.BytesIO(b"nine bytes")
        response.headers = {}
        with patch("update_formula.MAX_DOWNLOAD_BYTES", 8):
            with patch("update_formula.urllib.request.urlopen", return_value=response):
                with self.assertRaisesRegex(ValueError, "download limit"):
                    fetch_bytes("https://example.com/archive.tgz")

    def test_archive_member_limit_leaves_formula_unchanged(self):
        _, formula, replies = self.fixture("caliper")
        original = formula.read_text()
        with patch("update_formula.MAX_MEMBER_BYTES", 3):
            with self.assertRaisesRegex(ValueError, "size limit"):
                update(self.root, "caliper", "npm/caliper-docgen@0.6.0", replies.__getitem__)
        self.assertEqual(formula.read_text(), original)

    def test_downgrade_fails_before_fetch(self):
        _, formula, _ = self.fixture("callisto", "0.4.0")
        original = formula.read_text()
        with self.assertRaisesRegex(ValueError, "downgrade"):
            update(self.root, "callisto", "callisto@0.4.0", lambda _: self.fail("network fetch"))
        self.assertEqual(formula.read_text(), original)

    def test_latest_release_selection(self):
        config = load_tool(SOURCE_ROOT, "callisto")
        data = json.dumps([
            {"tag_name": "callisto@0.5.0", "draft": False, "prerelease": False},
            {"tag_name": "callisto@0.6.0", "draft": False, "prerelease": False},
            {"tag_name": "callisto@0.7.0-rc.1", "draft": False, "prerelease": True},
        ]).encode()
        self.assertEqual(latest_tag(config, lambda _: data), "callisto@0.6.0")

    def test_catalog_rejects_an_orphaned_formula_or_manifest(self):
        self.fixture("callisto")
        self.assertEqual(list_tools(self.root), ["callisto"])
        (self.root / "tools" / "callisto.json").unlink()
        with self.assertRaisesRegex(ValueError, "Every formula needs one tool manifest"):
            list_tools(self.root)
        (self.root / "Formula" / "callisto.rb").unlink()
        self.fixture("caliper")
        (self.root / "Formula" / "caliper.rb").unlink()
        with self.assertRaisesRegex(ValueError, "Every formula needs one tool manifest"):
            list_tools(self.root)


if __name__ == "__main__":
    unittest.main()
