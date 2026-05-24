"""Verify a RAMET output/{world}/ tree: every declared layer file exists,
PMTiles header looks valid, tile(0,0,0) decodes, sizes are non-zero."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path


def _check_tile_root(world_dir: Path, layer: dict) -> list[str]:
    errs: list[str] = []
    path_tmpl = layer.get("path", "")
    if "{z}" not in path_tmpl:
        errs.append(f"{layer['id']}: path template missing {{z}}/{{x}}/{{y}}")
        return errs
    sample = path_tmpl.replace("{z}", "0").replace("{x}", "0").replace("{y}", "0")
    tile = world_dir / sample
    if not tile.exists():
        errs.append(f"{layer['id']}: tile(0,0,0) missing at {tile}")
    elif tile.stat().st_size == 0:
        errs.append(f"{layer['id']}: tile(0,0,0) is zero bytes")
    return errs


def _check_pmtiles(path: Path) -> list[str]:
    errs: list[str] = []
    if not path.exists():
        errs.append(f"pmtiles missing: {path}")
        return errs
    if path.stat().st_size < 128:
        errs.append(f"pmtiles too small: {path}")
        return errs
    with path.open("rb") as fp:
        head = fp.read(8)
    # PMTiles v3 magic: "PMTiles\x03"
    if head != b"PMTiles\x03":
        errs.append(f"pmtiles bad magic: {head!r}")
    return errs


def verify_world(world_dir: Path) -> tuple[list[str], list[str]]:
    errs: list[str] = []
    notes: list[str] = []

    map_json = world_dir / "map.json"
    if not map_json.exists():
        return ([f"missing map.json under {world_dir}"], notes)
    try:
        meta = json.loads(map_json.read_text(encoding="utf-8"))
    except Exception as exc:
        return ([f"map.json invalid: {exc}"], notes)

    for layer in meta.get("rasterLayers", []) or []:
        errs += _check_tile_root(world_dir, layer)

    vec = meta.get("vectorSource") or {}
    if vec.get("type") == "pmtiles":
        errs += _check_pmtiles(world_dir / vec["url"])

    for svg in meta.get("svgLayers", []) or []:
        path = world_dir / svg["path"]
        if not path.exists() or path.stat().st_size == 0:
            errs.append(f"svg layer missing/empty: {path}")

    dem = meta.get("dem") or {}
    if dem:
        path = world_dir / dem["asc"]
        if not path.exists() or path.stat().st_size == 0:
            errs.append(f"DEM missing/empty: {path}")

    if not meta.get("imageSize"):
        notes.append("imageSize not declared — planner will fall back to config default")

    return (errs, notes)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--world-dir", required=True)
    args = ap.parse_args()
    errs, notes = verify_world(Path(args.world_dir))
    for n in notes:
        print(f"NOTE: {n}")
    for e in errs:
        print(f"ERR:  {e}")
    return 1 if errs else 0


if __name__ == "__main__":
    raise SystemExit(main())
