"""Verify a RAMET output/{world}/ tree.

Checks:
  * every advertised rasterLayer has tile(0,0,0) AND a sample at declared maxZoom
  * declared per-layer maxZoom matches deepest {z}/ dir present
  * no advertised layer has zero tiles (caught by drop-step in orchestrate, double-checked here)
  * PMTiles header is valid
  * SVG layers exist & non-empty
  * DEM is present & non-empty
  * sat_full.png present and >= 1 MB (warn) / fail if absent or zero-byte
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def _layer_path(layer: dict, z: int, x: int, y: int) -> str:
    return (
        layer.get("path", "")
        .replace("{z}", str(z))
        .replace("{x}", str(x))
        .replace("{y}", str(y))
    )


def _scan_zoom_dirs(layer_dir: Path) -> list[int]:
    if not layer_dir.is_dir():
        return []
    out = []
    for child in layer_dir.iterdir():
        if child.is_dir() and child.name.isdigit():
            # zoom dir is "real" only if it contains at least one tile file
            try:
                next(child.rglob("*"))
                out.append(int(child.name))
            except StopIteration:
                continue
    return sorted(out)


def _sample_tile_at_zoom(layer_dir: Path, z: int, ext: str) -> Path | None:
    z_dir = layer_dir / str(z)
    if not z_dir.is_dir():
        return None
    for x_dir in z_dir.iterdir():
        if not x_dir.is_dir():
            continue
        for tile in x_dir.glob(f"*.{ext}"):
            return tile
    return None


def _check_layer(world_dir: Path, layer: dict) -> list[str]:
    errs: list[str] = []
    lid = layer.get("id", "?")
    path_tmpl = layer.get("path", "")
    if "{z}" not in path_tmpl:
        errs.append(f"{lid}: path template missing {{z}}/{{x}}/{{y}}")
        return errs

    ext = layer.get("ext", "png")
    layer_dir = world_dir / "tiles" / lid

    tile000 = world_dir / _layer_path(layer, 0, 0, 0)
    if not tile000.exists():
        errs.append(f"{lid}: tile(0,0,0) missing at {tile000}")
    elif tile000.stat().st_size == 0:
        errs.append(f"{lid}: tile(0,0,0) is zero bytes")

    zooms = _scan_zoom_dirs(layer_dir)
    if not zooms:
        errs.append(f"{lid}: advertised in map.json but tile dir empty")
        return errs

    declared_max = layer.get("maxZoom")
    actual_max = zooms[-1]
    if declared_max is not None and int(declared_max) != actual_max:
        errs.append(
            f"{lid}: declared maxZoom={declared_max} != deepest dir {actual_max}"
        )

    sample = _sample_tile_at_zoom(layer_dir, actual_max, ext)
    if sample is None:
        errs.append(f"{lid}: no .{ext} tile present at deepest zoom {actual_max}")
    elif sample.stat().st_size == 0:
        errs.append(f"{lid}: sample tile at z={actual_max} is zero bytes ({sample})")
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
    if head != b"PMTiles\x03":
        errs.append(f"pmtiles bad magic: {head!r}")
    return errs


def _check_sat_source(world_dir: Path, arma_root_hint: Path | None) -> list[str]:
    """Warn-only style: emit error if sat_full.png absent/zero, warn if tiny."""
    # We can't always locate the upstream grad_meh/sat_full.png from world_dir alone;
    # check RAMET_Output/processed/{world}/source.json for a hint.
    src_json = world_dir / "source.json"
    if not src_json.exists():
        return []
    try:
        src = json.loads(src_json.read_text(encoding="utf-8"))
    except Exception:
        return []
    grad = src.get("grad_meh")
    if not grad:
        return []
    candidate = Path(grad) / "sat" / "sat_full.png"
    if not candidate.exists():
        return [f"sat source missing: {candidate}"]
    size = candidate.stat().st_size
    if size == 0:
        return [f"sat source zero-byte: {candidate}"]
    if size < 1024 * 1024:
        print(f"WARN: sat source small ({size} bytes): {candidate}")
    return []


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

    advertised_ids = set()
    for layer in meta.get("rasterLayers", []) or []:
        advertised_ids.add(layer.get("id"))
        errs += _check_layer(world_dir, layer)

    # Negative check: directories present in tiles/ but NOT in rasterLayers.
    tiles_root = world_dir / "tiles"
    if tiles_root.is_dir():
        for child in tiles_root.iterdir():
            if child.is_dir() and child.name not in advertised_ids:
                notes.append(f"tile dir present but not in rasterLayers: {child.name}")

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

    terrain3d = meta.get("terrain3d") or {}
    if terrain3d:
        path = world_dir / terrain3d.get("path", "3d/terrain.json")
        if not path.exists() or path.stat().st_size == 0:
            errs.append(f"3D terrain manifest missing/empty: {path}")
        elif not (world_dir / "3d" / "height_overview.bin").exists():
            errs.append(f"3D overview heights missing: {world_dir / '3d' / 'height_overview.bin'}")

    errs += _check_sat_source(world_dir, None)

    if not meta.get("imageSize"):
        notes.append("imageSize not declared — planner will fall back to config default")

    return (errs, notes)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("world_dir", nargs="?", help="RAMET_Output/processed/<world> dir")
    ap.add_argument("--world-dir", dest="wd_flag", help=argparse.SUPPRESS)
    args = ap.parse_args()
    target = args.world_dir or args.wd_flag
    if not target:
        print("usage: verify.py <world_dir>", file=sys.stderr)
        return 2
    errs, notes = verify_world(Path(target))
    for n in notes:
        print(f"NOTE: {n}")
    for e in errs:
        print(f"ERR:  {e}")
    return 1 if errs else 0


if __name__ == "__main__":
    raise SystemExit(main())
