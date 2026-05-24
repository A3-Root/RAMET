"""Deliver RAMET output to the planner.

Two modes:
  --local    copy <ramet_output>/{world}/ into <planner>/map_tiles/{world}/  (default)
  --zip      pack each world (or one bundle) into a zip for SFTP upload to a remote planner

Both modes are dependency-free (stdlib shutil + zipfile).
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import zipfile
from pathlib import Path

# Pipeline-mode default: <Arma3>/ramet_output. Override via RAMET_OUTPUT env or --output.
DEFAULT_OUTPUT = Path(os.environ.get(
    "RAMET_OUTPUT",
    str(Path(os.environ.get("RAMET_ARMA_ROOT", os.getcwd())) / "ramet_output"),
))
DEFAULT_PLANNER = Path(__file__).resolve().parent.parent.parent / "JSOC-OPS-Warlords" / "server" / "warlords" / "map_tiles"


def _list_worlds(output_dir: Path) -> list[str]:
    if not output_dir.is_dir():
        return []
    return sorted(p.name for p in output_dir.iterdir() if p.is_dir() and (p / "map.json").exists())


def deploy_local(output_dir: Path, planner_dir: Path, worlds: list[str] | None = None,
                 prune_legacy: bool = False, dry_run: bool = False) -> dict:
    summary: dict = {"mode": "local", "added": [], "replaced": [], "skipped": [], "pruned": []}
    planner_dir.mkdir(parents=True, exist_ok=True)

    if worlds is None:
        worlds = _list_worlds(output_dir)

    keep = set()
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
        keep.add(world)

    if prune_legacy:
        for child in planner_dir.iterdir():
            if not child.is_dir():
                continue
            if child.name in keep:
                continue
            if not (child / "map.json").exists():
                if not dry_run:
                    shutil.rmtree(child)
                summary["pruned"].append(child.name)
    return summary


def deploy_zip(output_dir: Path, zip_dir: Path, worlds: list[str] | None = None,
               bundle: bool = False, dry_run: bool = False) -> dict:
    """Per-world zip by default; --bundle merges all into one ramet_output_<ts>.zip."""
    summary: dict = {"mode": "zip", "bundle": bundle, "zips": [], "skipped": []}
    zip_dir.mkdir(parents=True, exist_ok=True)

    if worlds is None:
        worlds = _list_worlds(output_dir)

    if bundle:
        out_zip = zip_dir / "ramet_output_bundle.zip"
        if not dry_run:
            _zip_paths(out_zip, [(output_dir / w, w) for w in worlds if (output_dir / w / "map.json").exists()])
        summary["zips"].append({"path": str(out_zip), "worlds": worlds, "bytes": out_zip.stat().st_size if out_zip.exists() else 0})
        return summary

    for world in worlds:
        src = output_dir / world
        if not src.is_dir() or not (src / "map.json").exists():
            summary["skipped"].append(world)
            continue
        out_zip = zip_dir / f"{world}.zip"
        if not dry_run:
            _zip_paths(out_zip, [(src, world)])
        summary["zips"].append({
            "path": str(out_zip),
            "world": world,
            "bytes": out_zip.stat().st_size if out_zip.exists() else 0,
        })
    return summary


def _zip_paths(out_zip: Path, items: list[tuple[Path, str]]) -> None:
    """Write `out_zip` containing each (src_dir, arc_prefix) tree."""
    if out_zip.exists():
        out_zip.unlink()
    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for src, arc_prefix in items:
            for file in src.rglob("*"):
                if file.is_file():
                    arcname = f"{arc_prefix}/{file.relative_to(src).as_posix()}"
                    zf.write(file, arcname)


def main() -> int:
    ap = argparse.ArgumentParser(description="Deploy RAMET output to the planner.")
    ap.add_argument("--output", default=str(DEFAULT_OUTPUT), help="RAMET output dir (default: <Arma3>/ramet_output)")
    ap.add_argument("--world", action="append", help="restrict to specific world(s)")
    ap.add_argument("--dry-run", action="store_true")
    # local mode
    ap.add_argument("--local", action="store_true", help="copy into a local planner repo (default mode)")
    ap.add_argument("--planner-root", default=str(DEFAULT_PLANNER), help="planner map_tiles/ dir (--local)")
    ap.add_argument("--prune-legacy", action="store_true", help="(--local) delete planner-side maps absent from output")
    # zip mode
    ap.add_argument("--zip", action="store_true", help="produce zip(s) under <Arma3>/ramet_output/_zips/ for SFTP upload")
    ap.add_argument("--zip-dir", help="override zip output dir (default: <output>/_zips/)")
    ap.add_argument("--bundle", action="store_true", help="(--zip) emit one bundle zip instead of per-world zips")
    args = ap.parse_args()

    output_dir = Path(args.output)

    if args.zip:
        zip_dir = Path(args.zip_dir) if args.zip_dir else output_dir / "_zips"
        summary = deploy_zip(output_dir, zip_dir, worlds=args.world,
                             bundle=args.bundle, dry_run=args.dry_run)
    else:
        summary = deploy_local(output_dir, Path(args.planner_root), worlds=args.world,
                               prune_legacy=args.prune_legacy, dry_run=args.dry_run)

    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
