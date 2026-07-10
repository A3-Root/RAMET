#!/usr/bin/env python3
"""Find the hemtt-built root_amet zip, tag/release it on GitHub (idempotent),
and prune old releases beyond the retention count. Expects `hemtt release` to
have already run and GH_TOKEN to be set for `gh`.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

from packaging.version import InvalidVersion, Version #type:ignore

ROOT = Path(__file__).resolve().parents[2]
RELEASES_DIR = ROOT / "releases"
ZIP_RE = re.compile(r"^root_amet-(?P<version>.+)\.zip$")
RETAIN_RELEASES = 10


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=check)


def find_release_zip() -> tuple[Path, str]:
    if not RELEASES_DIR.is_dir():
        sys.exit(f"[auto_release] releases/ not found at {RELEASES_DIR} — did `hemtt release` run?")

    candidates = []
    for zip_path in RELEASES_DIR.glob("root_amet-*.zip"):
        match = ZIP_RE.match(zip_path.name)
        if not match:
            continue
        version_str = match.group("version")
        try:
            version = Version(version_str)
        except InvalidVersion:
            continue
        candidates.append((version, zip_path, version_str))

    if not candidates:
        sys.exit("[auto_release] No root_amet-*.zip found under releases/.")

    candidates.sort(key=lambda item: item[0])
    _, zip_path, version_str = candidates[-1]
    return zip_path, version_str


def existing_tags() -> set[str]:
    result = run("gh", "release", "list", "--json", "tagName", "--limit", "1000", check=False)
    if result.returncode != 0:
        print(f"[auto_release] WARN: gh release list failed: {result.stderr.strip()}")
        return set()
    return {entry["tagName"] for entry in json.loads(result.stdout or "[]")}


def prune_old_releases() -> None:
    result = run(
        "gh", "release", "list",
        "--json", "tagName,publishedAt",
        "--limit", "1000",
        check=False,
    )
    if result.returncode != 0:
        print(f"[auto_release] WARN: could not list releases for cleanup: {result.stderr.strip()}")
        return

    releases = json.loads(result.stdout or "[]")
    releases.sort(key=lambda entry: entry.get("publishedAt") or "", reverse=True)
    for entry in releases[RETAIN_RELEASES:]:
        tag = entry["tagName"]
        print(f"[auto_release] pruning old release {tag}")
        run("gh", "release", "delete", tag, "--yes", "--cleanup-tag", check=False)


def main() -> None:
    zip_path, version_str = find_release_zip()
    tag = f"v{version_str}"
    print(f"[auto_release] release artifact: {zip_path.name} (tag {tag})")

    if tag in existing_tags():
        print(f"[auto_release] {tag} already released — nothing to do.")
        return

    print(f"[auto_release] creating GitHub release {tag}")
    run(
        "gh", "release", "create", tag,
        str(zip_path),
        "--title", f"RAMET {tag}",
        "--generate-notes",
    )

    prune_old_releases()


if __name__ == "__main__":
    main()
