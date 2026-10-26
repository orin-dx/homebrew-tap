#!/usr/bin/env python3
"""Choose formula checks for a change while keeping shared changes comprehensive."""

import argparse
import json
import re
import subprocess
from typing import Optional
from update_formula import ROOT, list_tools

SHARED_PATHS = {".github/workflows/ci.yml", ".github/workflows/update-formula.yml"}
TOOL_PATH = re.compile(r"^(?:Formula/([a-z][a-z0-9-]*)\.rb|tools/([a-z][a-z0-9-]*)\.json)$")


def select_tools(paths: list[str], available: list[str]) -> list[str]:
    if any(path.startswith("scripts/") or path in SHARED_PATHS for path in paths):
        return available
    changed = {match.group(1) or match.group(2) for path in paths if (match := TOOL_PATH.fullmatch(path))}
    missing = changed.difference(available)
    if missing:
        raise ValueError(f"Changed formula has no tool manifest: {', '.join(sorted(missing))}")
    return sorted(changed)


def changed_paths(base: str) -> Optional[list[str]]:
    if not base or set(base) == {"0"}:
        return None
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--name-only", base, "HEAD", "--"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.splitlines()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="")
    parser.add_argument("--all", action="store_true", help="Check every formula, for a periodic full run")
    args = parser.parse_args()
    available = list_tools(ROOT)
    paths = None if args.all else changed_paths(args.base)
    print(json.dumps(available if paths is None else select_tools(paths, available)))
