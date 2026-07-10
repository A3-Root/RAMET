#!/usr/bin/env python3
"""Update the release/build-status badge in README.md after auto-release runs.
Idempotent: re-running replaces the previously-inserted badge block rather than
duplicating it. Commits and pushes the change directly (requires GH_TOKEN/git
credentials already set up by the workflow's checkout step).
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
README = ROOT / "README.md"
RELEASES_DIR = ROOT / "releases"
ZIP_RE = re.compile(r"^root_amet-(?P<version>.+)\.zip$")

BADGE_START = "<!-- RAMET-RELEASE-BADGE:START -->"
BADGE_END = "<!-- RAMET-RELEASE-BADGE:END -->"


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=check)


def latest_local_version() -> str | None:
    if not RELEASES_DIR.is_dir():
        return None
    versions = [
        match.group("version")
        for zip_path in RELEASES_DIR.glob("root_amet-*.zip")
        if (match := ZIP_RE.match(zip_path.name))
    ]
    return sorted(versions)[-1] if versions else None


def build_badge_block(status: str) -> str:
    if status == "success":
        version = latest_local_version() or "unknown"
        version_badge = f'<img src="https://img.shields.io/badge/release-v{version}-blue" alt="release">'
        build_badge = '<img src="https://img.shields.io/badge/build-passing-brightgreen" alt="build">'
    else:
        version_badge = existing_version_badge() or ""
        build_badge = '<img src="https://img.shields.io/badge/build-failing-red" alt="build">'

    parts = " ".join(p for p in (version_badge, build_badge) if p)
    return f"{BADGE_START}\n{parts}\n{BADGE_END}"


def existing_version_badge() -> str | None:
    if not README.is_file():
        return None
    text = README.read_text(encoding="utf-8")
    match = re.search(rf"{re.escape(BADGE_START)}\n(.*?)\n{re.escape(BADGE_END)}", text, re.DOTALL)
    if not match:
        return None
    for line in match.group(1).splitlines():
        if "release-" in line:
            return line.strip()
    return None


def upsert_badge(status: str) -> bool:
    if not README.is_file():
        sys.exit(f"[update_readme] README.md not found at {README}")

    text = README.read_text(encoding="utf-8")
    block = build_badge_block(status)

    pattern = re.compile(rf"{re.escape(BADGE_START)}\n.*?\n{re.escape(BADGE_END)}", re.DOTALL)
    if pattern.search(text):
        new_text = pattern.sub(block, text, count=1)
    else:
        # Insert right after the first top-level heading.
        lines = text.splitlines()
        insert_at = 1
        for i, line in enumerate(lines):
            if line.startswith("# "):
                insert_at = i + 1
                break
        lines[insert_at:insert_at] = ["", '<p align="center">', block, "</p>"]
        new_text = "\n".join(lines) + "\n"

    if new_text == text:
        print("[update_readme] no change needed.")
        return False

    README.write_text(new_text, encoding="utf-8")
    return True


def commit_and_push() -> None:
    run("git", "config", "user.name", "github-actions[bot]")
    run("git", "config", "user.email", "github-actions[bot]@users.noreply.github.com")
    run("git", "add", "README.md")

    status = run("git", "status", "--porcelain", check=False)
    if not status.stdout.strip():
        print("[update_readme] nothing staged, skipping commit.")
        return

    run("git", "commit", "-m", "chore: update release badge [skip ci]")
    push = run("git", "push", check=False)
    if push.returncode != 0:
        print(f"[update_readme] WARN: push failed: {push.stderr.strip()}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", choices=["success", "failure"], default="success")
    args = parser.parse_args()

    if upsert_badge(args.status):
        commit_and_push()


if __name__ == "__main__":
    main()
