#!/usr/bin/env python3
"""Keep the tap's version lines and merge the updater App's bump PRs.

`snapshot` opens a `tool@line` PR when a tool crosses into a new breaking line.
`merge` merges the App's bump and snapshot PRs once CI is green and the guards pass.
"""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import unquote

APP_LOGIN = "orin-dx-homebrew-updater[bot]"
REQUIRED_CHECKS = ("macOS ARM", "Linux x86-64", "Linux ARM")
STUCK_AFTER = timedelta(hours=24)

URL_LINE = re.compile(r'url "([^"]+)"')
SHA_LINE = re.compile(r'sha256 "([0-9a-f]{64})"')
SOURCE_URL = re.compile(r"(https://github\.com/[^/\"]+/[^/\"]+/archive/refs/tags/)(.+)\.tar\.gz")
FORMULA_PATH = re.compile(r"Formula/([a-z0-9][a-z0-9@.+-]*)\.rb")
VERSIONED_PATH = re.compile(r"Formula/([a-z0-9][a-z0-9.+-]*)@([0-9.]+)\.rb")


def version_key(version):
    return tuple(int(part) for part in version.split("."))


def breaking_line(version):
    """Before 1.0 every minor is a breaking line; from 1.0 every major is."""
    major, minor, _ = version.split(".")
    return f"0.{minor}" if major == "0" else major


def source_version(url):
    match = SOURCE_URL.fullmatch(url)
    # Decode first: in `callisto%400.15.0` the encoded `@` would otherwise run into the version.
    version = re.search(r"(?<![\d.])(\d+\.\d+\.\d+)$", unquote(match.group(2))) if match else None
    return version.group(1) if version else None


def formula_version(text):
    match = re.search(r'^  url "([^"]+)"', text, re.MULTILINE)
    version = source_version(match.group(1)) if match else None
    if version is None:
        raise ValueError("Formula has no GitHub source tarball URL with a version")
    return version


def make_snapshot(text):
    """Turn the current `tool` formula into the `tool@line` formula for its line."""
    line = breaking_line(formula_version(text))
    suffix = f"AT{line.replace('.', '')}"
    text, count = re.subn(r"^class (\w+) < Formula$", rf"class \1{suffix} < Formula", text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError("Formula has no class declaration")
    text = re.sub(r"^  head .*\n", "", text, flags=re.MULTILINE)
    text = re.sub(r"^  bottle do\n.*?^  end\n\n", "", text, flags=re.MULTILINE | re.DOTALL)
    any_version = r"(\d+(?:\.\d+)+)"
    pinned = rf"(0\.{line.split('.')[1]}\.\d+)" if line.startswith("0.") else rf"({line}(?:\.\d+)+)"
    if text.count(any_version) != 1:
        raise ValueError("Formula livecheck regex has an unexpected shape")
    text = text.replace(any_version, pinned)
    text, count = re.subn(
        r"(^  livecheck do\n.*?^  end\n\n)", r"\1  keg_only :versioned_formula\n\n", text, count=1,
        flags=re.MULTILINE | re.DOTALL,
    )
    if count != 1:
        raise ValueError("Formula has no livecheck block")
    return text


def check_bump(files, exists_on_main):
    """Return why a bump PR may not auto-merge, or None when it only moves source url and sha256."""
    if not files:
        return "no files changed"
    for changed in files:
        name = changed["filename"]
        match = FORMULA_PATH.fullmatch(name)
        if changed["status"] != "modified" or not match:
            return f"{name} is not a modified formula"
        urls = {"-": [], "+": []}
        shas = {"-": [], "+": []}
        for line in changed.get("patch", "").splitlines():
            if line.startswith("@@") or line[:1] not in ("+", "-"):
                continue
            sign, body = line[0], line[1:].strip()
            if match_url := URL_LINE.fullmatch(body):
                urls[sign].append(match_url.group(1))
            elif match_sha := SHA_LINE.fullmatch(body):
                shas[sign].append(match_sha.group(1))
            else:
                return f"{name} changes more than the source url and sha256"
        if any(len(group) != 1 for group in (*urls.values(), *shas.values())):
            return f"{name} must replace exactly one url and one sha256"
        old, new = urls["-"][0], urls["+"][0]
        old_source, new_source = SOURCE_URL.fullmatch(old), SOURCE_URL.fullmatch(new)
        if not old_source or not new_source or old_source.group(1) != new_source.group(1):
            return f"{name} must stay on the same GitHub source repository"
        old_version, new_version = source_version(old), source_version(new)
        if old_version is None or new_version is None or version_key(new_version) <= version_key(old_version):
            return f"{name} must move to a newer version"
        tool = match.group(1)
        old_line, new_line = breaking_line(old_version), breaking_line(new_version)
        if old_line != new_line:
            if "@" in tool:
                return f"{name} must stay within its own line"
            if not exists_on_main(f"Formula/{tool}@{old_line}.rb"):
                return f"Formula/{tool}@{old_line}.rb is not on main yet"
    return None


def check_snapshot(files, head_text, base_text_of):
    """Return why a snapshot PR may not auto-merge, or None when it is exactly the generated file."""
    if len(files) != 1 or files[0]["status"] != "added":
        return "a snapshot adds exactly one file"
    name = files[0]["filename"]
    match = VERSIONED_PATH.fullmatch(name)
    if not match:
        return f"{name} is not a versioned formula"
    base_text = base_text_of(f"Formula/{match.group(1)}.rb")
    if base_text is None:
        return f"Formula/{match.group(1)}.rb is not on main"
    try:
        expected = make_snapshot(base_text)
    except ValueError as error:
        return str(error)
    if f"Formula/{match.group(1)}@{breaking_line(formula_version(base_text))}.rb" != name:
        return f"{name} is not the line main is on"
    if head_text != expected:
        return f"{name} differs from the generated snapshot of main"
    return None


def gh(*args, token=None, stdin=None, check=True):
    env = {**os.environ, "GH_TOKEN": token} if token else os.environ
    result = subprocess.run(["gh", *args], input=stdin, capture_output=True, text=True, env=env)
    if check and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])} failed: {result.stderr.strip()}")
    return result


def api(path, *args, **kwargs):
    return json.loads(gh("api", path, *args, **kwargs).stdout or "null")


def file_at(repo, path, ref="main"):
    result = gh("api", f"repos/{repo}/contents/{path}?ref={ref}", check=False)
    if result.returncode != 0:
        return None
    return base64.b64decode(json.loads(result.stdout)["content"]).decode()


def open_issue_once(repo, title, body, token):
    found = gh("issue", "list", "--repo", repo, "--state", "open", "--search", f'"{title}" in:title',
               "--json", "title", token=token).stdout
    if any(issue["title"] == title for issue in json.loads(found)):
        return
    gh("issue", "create", "--repo", repo, "--title", title, "--body", body, token=token)


def merge_method(settings):
    """The merge method the repository allows: squash if enabled, else a merge commit, else rebase."""
    if settings.get("allow_squash_merge"):
        return "squash"
    return "merge" if settings.get("allow_merge_commit") else "rebase"


def merge_pull_requests(repo, dry_run):
    issue_token = os.environ.get("ISSUE_TOKEN")
    method = merge_method(api(f"repos/{repo}"))
    pulls = api(f"repos/{repo}/pulls?state=open&per_page=100")
    failed = False
    for pull in pulls:
        number, head = pull["number"], pull["head"]
        if pull["user"]["login"] != APP_LOGIN or head["repo"]["full_name"] != repo or pull["base"]["ref"] != "main":
            continue
        files = api(f"repos/{repo}/pulls/{number}/files?per_page=100")
        if any(changed["status"] == "added" for changed in files):
            head_text = file_at(repo, files[0]["filename"], head["sha"]) if len(files) == 1 else None
            reason = check_snapshot(files, head_text, lambda path: file_at(repo, path))
        else:
            reason = check_bump(files, lambda path: file_at(repo, path) is not None)
        if reason is None:
            runs = api(f"repos/{repo}/commits/{head['sha']}/check-runs?per_page=100")["check_runs"]
            results = {run["name"]: run["conclusion"] for run in runs}
            waiting = [name for name in REQUIRED_CHECKS if results.get(name) != "success"]
            if waiting:
                reason = f"waiting for {', '.join(waiting)}"
        if reason is None:
            print(f"#{number}: merging with {method}")
            if dry_run:
                continue
            try:
                gh("api", "-X", "PUT", f"repos/{repo}/pulls/{number}/merge", "-f", f"merge_method={method}",
                   "-f", f"sha={head['sha']}")
                continue
            except RuntimeError as error:
                reason, failed = f"the merge failed: {error}", True
        print(f"#{number}: not merging: {reason}")
        age = datetime.now(timezone.utc) - datetime.fromisoformat(pull["created_at"].replace("Z", "+00:00"))
        if age > STUCK_AFTER and issue_token and not dry_run:
            open_issue_once(repo, f"Bump PR #{number} has not merged",
                            f"{pull['html_url']} has been open for over a day. Last status: {reason}.", issue_token)
    return 1 if failed else 0


def open_snapshot_prs(repo, tap_dir, livecheck_file, dry_run):
    for entry in json.load(open(livecheck_file)):
        name, versions = entry["formula"].split("/")[-1], entry["version"]
        if "@" in name or breaking_line(versions["current"]) == breaking_line(versions["latest"]):
            continue
        line = breaking_line(versions["current"])
        path = f"Formula/{name}@{line}.rb"
        if os.path.exists(os.path.join(tap_dir, path)):
            continue
        content = make_snapshot(open(os.path.join(tap_dir, f"Formula/{name}.rb")).read())
        branch, title = f"snapshot/{name}-{line}", f"feat({name}@{line}): keep the {line} line installable"
        print(f"{name}: {versions['current']} -> {versions['latest']} crosses into a new line; snapshotting {line}")
        if dry_run:
            continue
        main_sha = api(f"repos/{repo}/git/ref/heads/main")["object"]["sha"]
        existing = gh("api", f"repos/{repo}/git/ref/heads/{branch}", check=False)
        if existing.returncode != 0:
            gh("api", f"repos/{repo}/git/refs", "-f", f"ref=refs/heads/{branch}", "-f", f"sha={main_sha}")
        current = gh("api", f"repos/{repo}/contents/{path}?ref={branch}", check=False)
        body = {"message": title, "branch": branch, "content": base64.b64encode(content.encode()).decode()}
        if current.returncode == 0:
            if base64.b64decode(json.loads(current.stdout)["content"]).decode() == content:
                continue
            body["sha"] = json.loads(current.stdout)["sha"]
        gh("api", "-X", "PUT", f"repos/{repo}/contents/{path}", "--input", "-", stdin=json.dumps(body))
        if not api(f"repos/{repo}/pulls?head={repo.split('/')[0]}:{branch}&state=open"):
            gh("pr", "create", "--repo", repo, "--base", "main", "--head", branch, "--title", title, "--body",
               f"`{name}` is about to move to {versions['latest']}, a new breaking line. This keeps the "
               f"{line} line installable as `{name}@{line}`: keg-only, no bottle or head line, livecheck "
               "pinned to the line. It must merge before the bump PR, which waits for it.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    merge = commands.add_parser("merge")
    merge.add_argument("--repo", required=True)
    merge.add_argument("--dry-run", action="store_true")
    snapshot = commands.add_parser("snapshot")
    snapshot.add_argument("--repo", required=True)
    snapshot.add_argument("--tap-dir", required=True)
    snapshot.add_argument("--livecheck", required=True)
    snapshot.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.command == "merge":
        return merge_pull_requests(args.repo, args.dry_run)
    open_snapshot_prs(args.repo, args.tap_dir, args.livecheck, args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
