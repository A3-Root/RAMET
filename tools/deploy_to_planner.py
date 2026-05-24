"""Sync RAMET output/ into JSOC-OPS-Warlords/server/warlords/map_tiles/.

Default planner path is resolved relative to this repo (sibling dir).
Override with --planner-root <path>.

Operation per world:
  - removes the existing map_tiles/<world>/ if present (clean replace)
  - copies output/<world>/* in
  - emits a per-run summary on stdout (added / replaced / kept-only)

The script is intentionally dependency-free — uses shutil only — so it runs
on any Python 3.10+ without rsync available.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

DEFAULT_OUTPUT = Path(__file__).resolve().parent.parent / "output"
DEFAULT_PLANNER = Path(__file__).resolve().parent.parent.parent / "JSOC-OPS-Warlords" / "server" / "warlords" / "map_tiles"


def _list_worlds(output_dir: Path) -> list[str]:
    if not output_dir.is_dir():
        return []
    return sorted(p.name for p in output_dir.iterdir() if p.is_dir() and (p / "map.json").exists())


def deploy(output_dir: Path, planner_dir: Path, worlds: list[str] | None = None,
           prune_legacy: bool = False, dry_run: bool = False) -> dict:
    summary: dict = {"added": [], "replaced": [], "skipped": [], "pruned": [], "errors": []}
    planner_dir.mkdir(parents=True, exist_ok=True)

    if worlds is None:
        worlds = _list_worlds(output_dir)

    legacy_keep = set()
    for world in worlds:
        src = output_dir / world
        dst = planner_dir / world
        if not src.is_dir() or not (src / "map.json").exists():
            summary["skipped"].append(world)
            continue
        action = "replaced" if dst.exists() else "added"
        if not dry_run:
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        summary[action].append(world)
        legacy_keep.add(world)

    if prune_legacy:
        for child in planner_dir.iterdir():
            if not child.is_dir():
                continue
            if child.name in legacy_keep:
                continue
            if not (child / "map.json").exists():
                # legacy OCAP-only map — leave alone unless pruning
                if not dry_run:
                    shutil.rmtree(child)
                summary["pruned"].append(child.name)

    return summary


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default=str(DEFAULT_OUTPUT), help="RAMET output/ dir")
    ap.add_argument("--planner-root", default=str(DEFAULT_PLANNER),
                    help="planner map_tiles/ dir")
    ap.add_argument("--world", action="append", help="restrict to specific world(s)")
    ap.add_argument("--prune-legacy", action="store_true",
                    help="delete planner-side maps that lack a RAMET map.json")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    summary = deploy(
        Path(args.output),
        Path(args.planner_root),
        worlds=args.world,
        prune_legacy=args.prune_legacy,
        dry_run=args.dry_run,
    )
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
