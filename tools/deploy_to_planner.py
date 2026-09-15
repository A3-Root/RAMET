"""Deliver RAMET output to a user-supplied deployment target.

Two modes:
  --local    copy <RAMET_Output/processed>/{world}/ into <planner>/map_tiles/{world}/  (default)
  --zip      pack each world (or one bundle) into a zip for SFTP upload to a remote planner

By default both modes pack the loose raster pyramid (tiles/<variant>/<z>/<x>/<y>.<ext>) into a
single {world}/tiles.sqlite (format "warlords-tiles-1", read by the JSOC-OPS-Warlords planner)
instead of shipping hundreds of thousands of loose files. Pass --loose for the old behaviour.

Both modes are dependency-free (stdlib shutil + sqlite3 + zipfile).
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
import zipfile
from pathlib import Path

# Pipeline-mode default: <Arma3>/RAMET_Output/processed. Override via RAMET_OUTPUT env or --output.
DEFAULT_OUTPUT = Path(os.environ.get(
    "RAMET_OUTPUT",
    str(Path(os.environ.get("RAMET_ARMA_ROOT", os.getcwd())) / "RAMET_Output" / "processed"),
))

# Packed tile format shared with JSOC-OPS-Warlords server/tools/pack_map_tiles.py — keep in sync.
PACK_NAME = "tiles.sqlite"
PACK_FORMAT = "warlords-tiles-1"
TILE_EXTS = {"png", "webp", "jpg", "jpeg"}
PACK_BATCH = 2000


def _list_worlds(output_dir: Path) -> list[str]:
    if not output_dir.is_dir():
        return []
    return sorted(p.name for p in output_dir.iterdir() if p.is_dir() and (p / "map.json").exists())


def _iter_loose_tiles(world_dir: Path):
    """Yield (variant, z, x, y, ext, path) for every tile under world_dir/tiles/."""
    tiles_dir = world_dir / "tiles"
    if not tiles_dir.is_dir():
        return
    for variant in sorted(os.scandir(tiles_dir), key=lambda e: e.name):
        if not variant.is_dir():
            continue
        for z_entry in os.scandir(variant.path):
            if not (z_entry.is_dir() and z_entry.name.isdigit()):
                continue
            for x_entry in os.scandir(z_entry.path):
                if not (x_entry.is_dir() and x_entry.name.isdigit()):
                    continue
                for tile in os.scandir(x_entry.path):
                    stem, _, ext = tile.name.rpartition(".")
                    ext = ext.lower()
                    if ext not in TILE_EXTS or not stem.isdigit() or not tile.is_file():
                        continue
                    yield variant.name, int(z_entry.name), int(x_entry.name), int(stem), ext, tile.path


def _has_loose_tiles(world_dir: Path) -> bool:
    return next(_iter_loose_tiles(world_dir), None) is not None


def pack_tiles(world_dir: Path, pack_path: Path) -> int:
    """Write world_dir/tiles/ into a tiles.sqlite at pack_path. Returns the tile count."""
    tmp = pack_path.with_name(pack_path.name + ".tmp")
    tmp.unlink(missing_ok=True)
    conn = sqlite3.connect(tmp)
    try:
        conn.execute("PRAGMA journal_mode = OFF")
        conn.execute("PRAGMA synchronous = OFF")
        conn.execute("PRAGMA page_size = 16384")
        conn.executescript(
            "CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT NOT NULL);"
            "CREATE TABLE tiles (variant TEXT NOT NULL, z INTEGER NOT NULL, x INTEGER NOT NULL,"
            " y INTEGER NOT NULL, ext TEXT NOT NULL, data BLOB NOT NULL);"
        )
        count = 0
        total_bytes = 0
        batch = []
        for variant, z, x, y, ext, path in _iter_loose_tiles(world_dir):
            with open(path, "rb") as handle:
                data = handle.read()
            batch.append((variant, z, x, y, ext, data))
            count += 1
            total_bytes += len(data)
            if len(batch) >= PACK_BATCH:
                conn.executemany("INSERT INTO tiles VALUES (?, ?, ?, ?, ?, ?)", batch)
                conn.commit()
                batch.clear()
        if batch:
            conn.executemany("INSERT INTO tiles VALUES (?, ?, ?, ?, ?, ?)", batch)
        conn.execute("CREATE UNIQUE INDEX tiles_key ON tiles (variant, z, x, y, ext)")
        conn.executemany(
            "INSERT INTO metadata VALUES (?, ?)",
            [("format", PACK_FORMAT), ("tile_count", str(count)), ("tile_bytes", str(total_bytes))],
        )
        conn.commit()
    finally:
        conn.close()
    os.replace(tmp, pack_path)
    return count


def _ignore_top_level_tiles(root: Path):
    """shutil.copytree ignore callback that skips only <root>/tiles."""
    def ignore(directory: str, names: list[str]) -> set[str]:
        return {"tiles"} if Path(directory) == root and "tiles" in names else set()
    return ignore


def deploy_local(output_dir: Path, planner_dir: Path, worlds: list[str] | None = None,
                 prune_legacy: bool = False, dry_run: bool = False, loose: bool = False) -> dict:
    summary: dict = {"mode": "local", "added": [], "replaced": [], "skipped": [], "pruned": [], "packed": {}}
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
        pack = not loose and _has_loose_tiles(src)
        if not dry_run:
            # Pack beside the planner folder first so a failed pack leaves the deployed world intact.
            # A dot-prefixed file (not a directory) is never listed as a map by the planner.
            staged_pack = planner_dir / f".{world}.{PACK_NAME}"
            if pack:
                summary["packed"][world] = pack_tiles(src, staged_pack)
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(src, dst, ignore=_ignore_top_level_tiles(src) if pack else None)
            if pack:
                os.replace(staged_pack, dst / PACK_NAME)
        elif pack:
            summary["packed"][world] = "dry-run"
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
               bundle: bool = False, dry_run: bool = False, loose: bool = False) -> dict:
    """Per-world zip by default; --bundle merges all into one RAMET_Output_<ts>.zip."""
    summary: dict = {"mode": "zip", "bundle": bundle, "zips": [], "skipped": [], "packed": {}}
    zip_dir.mkdir(parents=True, exist_ok=True)

    if worlds is None:
        worlds = _list_worlds(output_dir)

    if bundle:
        out_zip = zip_dir / "RAMET_Output_bundle.zip"
        if not dry_run:
            items = [(output_dir / w, w) for w in worlds if (output_dir / w / "map.json").exists()]
            summary["packed"] = _zip_paths(out_zip, items, zip_dir, loose)
        summary["zips"].append({"path": str(out_zip), "worlds": worlds, "bytes": out_zip.stat().st_size if out_zip.exists() else 0})
        return summary

    for world in worlds:
        src = output_dir / world
        if not src.is_dir() or not (src / "map.json").exists():
            summary["skipped"].append(world)
            continue
        out_zip = zip_dir / f"{world}.zip"
        if not dry_run:
            summary["packed"].update(_zip_paths(out_zip, [(src, world)], zip_dir, loose))
        summary["zips"].append({
            "path": str(out_zip),
            "world": world,
            "bytes": out_zip.stat().st_size if out_zip.exists() else 0,
        })
    return summary


def _zip_paths(out_zip: Path, items: list[tuple[Path, str]], work_dir: Path, loose: bool) -> dict:
    """Write `out_zip` containing each (src_dir, arc_prefix) tree. Returns {arc_prefix: packed tile count}."""
    packed: dict = {}
    if out_zip.exists():
        out_zip.unlink()
    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for src, arc_prefix in items:
            pack = not loose and _has_loose_tiles(src)
            for file in src.rglob("*"):
                if not file.is_file():
                    continue
                rel = file.relative_to(src)
                if pack and rel.parts[0] == "tiles":
                    continue
                zf.write(file, f"{arc_prefix}/{rel.as_posix()}")
            if pack:
                staged_pack = work_dir / f".{arc_prefix}.{PACK_NAME}"
                try:
                    packed[arc_prefix] = pack_tiles(src, staged_pack)
                    # Tile images are already compressed; storing avoids a slow, useless deflate pass.
                    zf.write(staged_pack, f"{arc_prefix}/{PACK_NAME}", compress_type=zipfile.ZIP_STORED)
                finally:
                    staged_pack.unlink(missing_ok=True)
    return packed


def main() -> int:
    ap = argparse.ArgumentParser(description="Deploy RAMET output to the planner.")
    ap.add_argument("--output", default=str(DEFAULT_OUTPUT), help="RAMET output dir (default: <Arma3>/RAMET_Output/processed)")
    ap.add_argument("--world", action="append", help="restrict to specific world(s)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--loose", action="store_true",
                    help="ship loose tiles/ folders instead of packing them into tiles.sqlite")
    # local mode
    ap.add_argument("--local", action="store_true", help="copy into a local planner repo (default mode)")
    ap.add_argument("--planner-root", help="planner map_tiles/ dir (--local); required unless RAMET_PLANNER_ROOT is set")
    ap.add_argument("--prune-legacy", action="store_true", help="(--local) delete planner-side maps absent from output")
    # zip mode
    ap.add_argument("--zip", action="store_true", help="produce zip(s) under <Arma3>/RAMET_Output/_zips/ for SFTP upload")
    ap.add_argument("--zip-dir", help="override zip output dir (default: <output>/_zips/)")
    ap.add_argument("--bundle", action="store_true", help="(--zip) emit one bundle zip instead of per-world zips")
    args = ap.parse_args()

    output_dir = Path(args.output)

    if args.zip:
        zip_dir = Path(args.zip_dir) if args.zip_dir else output_dir / "_zips"
        summary = deploy_zip(output_dir, zip_dir, worlds=args.world,
                             bundle=args.bundle, dry_run=args.dry_run, loose=args.loose)
    else:
        planner_root = args.planner_root or os.environ.get("RAMET_PLANNER_ROOT")
        if not planner_root:
            print("ERR: --planner-root is required for local deploy (or set RAMET_PLANNER_ROOT)", file=sys.stderr)
            return 2
        summary = deploy_local(output_dir, Path(planner_root), worlds=args.world,
                               prune_legacy=args.prune_legacy, dry_run=args.dry_run, loose=args.loose)

    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
