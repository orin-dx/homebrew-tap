#!/usr/bin/env python3
"""Verify published tool archives and update one Homebrew formula."""

import argparse
import base64
import hashlib
import hmac
import io
import json
import os
import re
import tarfile
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
TARGET_IDS = {"macos-arm64", "macos-x64", "linux-arm64", "linux-x64"}
MAX_DOWNLOAD_BYTES = 64 * 1024 * 1024
MAX_MEMBER_BYTES = 64 * 1024 * 1024
MAX_PACKAGE_JSON_BYTES = 1024 * 1024


def fetch_bytes(url: str) -> bytes:
    headers = {"User-Agent": "orin-dx-homebrew-tap"}
    if url.startswith("https://api.github.com/"):
        headers["Accept"] = "application/vnd.github+json"
        if token := os.environ.get("GH_TOKEN"):
            headers["Authorization"] = f"Bearer {token}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        content_length = response.headers.get("Content-Length")
        if content_length is not None and int(content_length) > MAX_DOWNLOAD_BYTES:
            raise ValueError("Release response exceeds the download limit")
        data = response.read(MAX_DOWNLOAD_BYTES + 1)
        if len(data) > MAX_DOWNLOAD_BYTES:
            raise ValueError("Release response exceeds the download limit")
        return data


def load_tool(root: Path, tool: str) -> dict:
    if not re.fullmatch(r"[a-z][a-z0-9-]*", tool):
        raise ValueError("Invalid tool name")
    config = json.loads((root / "tools" / f"{tool}.json").read_text())
    targets = config["targets"]
    if {target["id"] for target in targets} != TARGET_IDS or len(targets) != len(TARGET_IDS):
        raise ValueError("Every tool needs one archive for each supported platform")
    if config["provider"] not in {"github-release", "npm-platform"}:
        raise ValueError("Unknown release provider")
    if config["formula"] != f"Formula/{tool}.rb":
        raise ValueError("Formula path must match the tool")
    for target in targets:
        if not isinstance(target.get("explicitVersion", False), bool):
            raise ValueError("Explicit version flag must be a boolean")
        if target["url"].count("{version}") != 1 or not target["url"].startswith("https://"):
            raise ValueError("Each target needs one HTTPS versioned URL")
        if target["binary"] not in target["members"] or len(set(target["members"])) != len(target["members"]):
            raise ValueError("Archive members must include exactly one binary")
    return config


def list_tools(root: Path) -> list[str]:
    tools = sorted(path.stem for path in (root / "tools").glob("*.json"))
    formulas = {path.stem for path in (root / "Formula").glob("*.rb")}
    if formulas != set(tools):
        raise ValueError("Every formula needs one tool manifest, and every tool needs one formula")
    if not tools:
        raise ValueError("No tool manifests found")
    for tool in tools:
        load_tool(root, tool)
    return tools


def formula_versions(source: str, targets: list[dict]) -> tuple[str, list[re.Pattern]]:
    explicit_versions = re.findall(r'^[ \t]+version "(' + VERSION + r')"$', source, re.MULTILINE)
    expected_explicit = sum(target.get("explicitVersion", False) for target in targets)
    if len(explicit_versions) != expected_explicit:
        raise ValueError("Formula explicit version count differs from the tool manifest")
    if len(re.findall(r'^\s+url "', source, re.MULTILINE)) != len(targets):
        raise ValueError("Formula URL count differs from the tool manifest")
    if len(re.findall(r'^\s+sha256 "', source, re.MULTILINE)) != len(targets):
        raise ValueError("Formula SHA-256 count differs from the tool manifest")
    versions = set()
    patterns = []
    for target in targets:
        before, after = target["url"].split("{version}")
        pattern = re.compile(
            r'(url "' + re.escape(before) + r')(?P<version>' + VERSION + r')('
            + re.escape(after) + r'"\n\s+sha256 ")(?P<sha>[0-9a-f]{64})(")'
        )
        found = list(pattern.finditer(source))
        if len(found) != 1:
            raise ValueError(f"Expected one URL and checksum for {target['id']}")
        url_line_start = source.rfind("\n", 0, found[0].start()) + 1
        previous_lines = source[:url_line_start].splitlines()
        previous_line = previous_lines[-1] if previous_lines else ""
        has_override = re.fullmatch(r'[ \t]+version "' + VERSION + r'"', previous_line) is not None
        if has_override != target.get("explicitVersion", False):
            raise ValueError(f"Explicit version placement disagrees for {target['id']}")
        versions.add(found[0].group("version"))
        patterns.append(pattern)
    if len(versions) != 1:
        raise ValueError("Formula target versions disagree")
    target_version = versions.pop()
    if any(explicit_version != target_version for explicit_version in explicit_versions):
        raise ValueError("Formula version disagrees with target URLs")
    return target_version, patterns


def archive_digest(config: dict, target: dict, version: str, get: Callable[[str], bytes]) -> str:
    expected_url = target["url"].format(version=version)
    if config["provider"] == "github-release":
        tag = f"{config['tagPrefix']}{version}"
        api = f"https://api.github.com/repos/{config['repository']}/releases/tags/{urllib.parse.quote(tag, safe='')}"
        release = json.loads(get(api))
        if release.get("tag_name") != tag or release.get("draft") is not False or release.get("prerelease") is not False:
            raise ValueError("Expected a published, stable GitHub release")
        matches = [asset for asset in release["assets"] if asset["name"] == target["asset"]]
        if len(matches) != 1 or matches[0].get("browser_download_url") != expected_url:
            raise ValueError(f"Missing or unexpected release asset for {target['id']}")
        digest = matches[0].get("digest")
        if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise ValueError(f"Missing GitHub SHA-256 for {target['id']}")
        expected = bytes.fromhex(digest.removeprefix("sha256:"))
        algorithm = "sha256"
    else:
        package = target["package"]
        api = f"https://registry.npmjs.org/{package}/{version}"
        metadata = json.loads(get(api))
        if metadata.get("name") != package or metadata.get("version") != version:
            raise ValueError(f"Unexpected npm package metadata for {target['id']}")
        dist = metadata["dist"]
        if dist.get("tarball") != expected_url:
            raise ValueError(f"Unexpected npm tarball URL for {target['id']}")
        integrity = dist.get("integrity")
        if not isinstance(integrity, str) or not integrity.startswith("sha512-"):
            raise ValueError(f"Missing npm SHA-512 integrity for {target['id']}")
        expected = base64.b64decode(integrity.removeprefix("sha512-"), validate=True)
        if len(expected) != 64:
            raise ValueError(f"Invalid npm integrity digest for {target['id']}")
        algorithm = "sha512"

    archive = get(expected_url)
    if not hmac.compare_digest(hashlib.new(algorithm, archive).digest(), expected):
        raise ValueError(f"Archive does not match published digest for {target['id']}")
    expected_members = set(target["members"])
    seen = set()
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        for member in tar:
            if member.name not in expected_members or member.name in seen:
                raise ValueError(f"Unexpected archive contents for {target['id']}")
            seen.add(member.name)
            if not member.isfile():
                raise ValueError(f"Non-file archive member for {target['id']}")
            if member.size > MAX_MEMBER_BYTES:
                raise ValueError(f"Archive member exceeds the size limit for {target['id']}")
            if member.name == target["binary"] and member.mode & 0o111 == 0:
                raise ValueError(f"Binary is not executable for {target['id']}")
            if config["provider"] == "npm-platform" and member.name == "package/package.json":
                if member.size > MAX_PACKAGE_JSON_BYTES:
                    raise ValueError(f"Package metadata exceeds the size limit for {target['id']}")
                package_file = tar.extractfile(member)
                if package_file is None:
                    raise ValueError(f"Unreadable package metadata for {target['id']}")
                manifest = json.load(package_file)
                if manifest.get("name") != target["package"] or manifest.get("version") != version:
                    raise ValueError(f"Archive package identity differs for {target['id']}")
        if seen != expected_members:
            raise ValueError(f"Unexpected archive contents for {target['id']}")
    return hashlib.sha256(archive).hexdigest()


def latest_tag(config: dict, get: Callable[[str], bytes]) -> str:
    if config["provider"] == "github-release":
        url = f"https://api.github.com/repos/{config['repository']}/releases?per_page=100"
        releases = json.loads(get(url))
        versions = [
            release["tag_name"].removeprefix(config["tagPrefix"])
            for release in releases
            if release.get("tag_name", "").startswith(config["tagPrefix"])
            and re.fullmatch(VERSION, release["tag_name"][len(config["tagPrefix"]):])
            and release.get("draft") is False
            and release.get("prerelease") is False
        ]
        if not versions:
            raise ValueError("No published stable release found")
        version = max(versions, key=lambda value: tuple(map(int, value.split("."))))
    else:
        package = config["tagPrefix"].removeprefix("npm/").removesuffix("@")
        metadata = json.loads(get(f"https://registry.npmjs.org/{package}/latest"))
        version = metadata.get("version", "")
        if metadata.get("name") != package or not re.fullmatch(VERSION, version):
            raise ValueError("No stable npm latest version found")
    return f"{config['tagPrefix']}{version}"


def update(root: Path, tool: str, tag: str, get: Callable[[str], bytes] = fetch_bytes) -> str:
    config = load_tool(root, tool)
    prefix = config["tagPrefix"]
    if not tag.startswith(prefix) or not re.fullmatch(VERSION, tag[len(prefix):]):
        raise ValueError(f"Expected a stable {prefix}X.Y.Z tag")
    version = tag[len(prefix):]
    formula = root / config["formula"]
    source = formula.read_text()
    old_version, patterns = formula_versions(source, config["targets"])
    if tuple(map(int, version.split("."))) < tuple(map(int, old_version.split("."))):
        raise ValueError("Refusing to downgrade the formula")
    cache: dict[str, bytes] = {}

    def cached_get(url: str) -> bytes:
        if url not in cache:
            cache[url] = get(url)
        return cache[url]

    digests = [archive_digest(config, target, version, cached_get) for target in config["targets"]]
    updated, version_count = re.subn(
        r'^([ \t]+version ")' + re.escape(old_version) + r'("$)',
        lambda match: match.group(1) + version + match.group(2),
        source,
        flags=re.MULTILINE,
    )
    if version_count != sum(target.get("explicitVersion", False) for target in config["targets"]):
        raise ValueError("Formula version changed while updating")
    for target, pattern, digest in zip(config["targets"], patterns, digests):
        updated, count = pattern.subn(
            lambda match: match.group(1) + version + match.group(3) + digest + match.group(5),
            updated,
        )
        if count != 1:
            raise ValueError(f"Formula changed while updating {target['id']}")
    if updated != source:
        formula.write_text(updated)
    return version


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool")
    parser.add_argument("--list-tools", action="store_true")
    parser.add_argument("--validate-tool")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--tag")
    source.add_argument("--latest", action="store_true")
    args = parser.parse_args()
    if args.list_tools:
        if args.tool or args.tag or args.latest or args.validate_tool:
            parser.error("--list-tools cannot be combined with an update")
        print(json.dumps(list_tools(ROOT)))
    elif args.validate_tool:
        if args.tool or args.tag or args.latest:
            parser.error("--validate-tool cannot be combined with an update")
        load_tool(ROOT, args.validate_tool)
    else:
        if not args.tool or not (args.tag or args.latest):
            parser.error("An update needs --tool and either --tag or --latest")
        release_tag = latest_tag(load_tool(ROOT, args.tool), fetch_bytes) if args.latest else args.tag
        print(update(ROOT, args.tool, release_tag))
