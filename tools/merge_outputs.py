"""Unify grad_meh + ocap-rt intermediate outputs into one output/{world}/ tree.

Inputs (under <root>/_intermediate/):
    grad_meh/{world}/  — sat pyramid, geojsons, dem, meta.json
    ocap_rt/{world}/   — topo* pyramids, GeoTIFFs, full SVG, ASC

Output: <root>/output/{world}/ structured per docs/SCHEMA.md.

Conflict policy: when both tools emit the same raster variant (e.g. both
produce a `topo` pyramid), ocap-rt wins (higher fidelity).
"""

from __future__ import annotations

import gzip
import json
import shutil
from pathlib import Path
from typing import Any

OCAP_VARIANT_DIRS = {
    "topo": "topo",
    "topoDark": "topo_dark",
    "topoRelief": "topoRelief",
    "colorRelief": "colorRelief",
}

GRAD_VARIANT_DIRS = {
    "sat": "sat",
    "sat_dark": "sat_dark",
    "baked_sat": "baked_sat",
}


def _copy_pyramid(src: Path, dst: Path) -> bool:
    if not src.is_dir():
        return False
    if dst.exists():
        shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(src, dst)
    return True


def _gz_in_place(src: Path, dst_gz: Path) -> bool:
    if not src.exists():
        return False
    dst_gz.parent.mkdir(parents=True, exist_ok=True)
    with src.open("rb") as fp_in, gzip.open(dst_gz, "wb") as fp_out:
        shutil.copyfileobj(fp_in, fp_out)
    return True


def _read_grad_meta(grad_dir: Path) -> dict[str, Any]:
    meta_path = grad_dir / "meta.json"
    if not meta_path.exists():
        return {}
    try:
        return json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def merge_world(world: str, grad_dir: Path | None, ocap_dir: Path | None,
                out_dir: Path) -> dict:
    """Produce out_dir/{world}/* from the two inputs. Either may be None.
    Returns the raw `map.json` dict (not written here — orchestrate.py owns that)."""
    world_out = out_dir / world
    world_out.mkdir(parents=True, exist_ok=True)
    (world_out / "tiles").mkdir(exist_ok=True)
    (world_out / "vector").mkdir(exist_ok=True)
    (world_out / "svg" / "layers").mkdir(parents=True, exist_ok=True)
    (world_out / "dem").mkdir(exist_ok=True)

    sources: list[str] = []
    raster_layers: list[dict] = []
    svg_layers: list[dict] = []

    # ---- ocap-rt rasters (win on conflict) ----
    if ocap_dir and ocap_dir.is_dir():
        sources.append("ocap")
        for ocap_name, out_name in OCAP_VARIANT_DIRS.items():
            src = ocap_dir / ocap_name
            if _copy_pyramid(src, world_out / "tiles" / out_name):
                raster_layers.append({
                    "id": out_name,
                    "path": f"tiles/{out_name}/{{z}}/{{x}}/{{y}}.png",
                    "label": out_name.replace("_", " ").title(),
                    "category": "base",
                    "ext": "png",
                })
        # SVG
        svg_src = ocap_dir / "map.svg"
        if svg_src.exists():
            _gz_in_place(svg_src, world_out / "svg" / "full.svg.gz")
        # ASC heightmap
        asc_src = ocap_dir / "heightmap.asc"
        if asc_src.exists():
            _gz_in_place(asc_src, world_out / "dem" / "dem.asc.gz")

    # ---- grad_meh rasters (only fill what ocap didn't) ----
    if grad_dir and grad_dir.is_dir():
        sources.append("grad_meh")
        for grad_name, out_name in GRAD_VARIANT_DIRS.items():
            src = grad_dir / grad_name
            if _copy_pyramid(src, world_out / "tiles" / out_name):
                raster_layers.append({
                    "id": out_name,
                    "path": f"tiles/{out_name}/{{z}}/{{x}}/{{y}}.webp",
                    "label": "Satellite" if out_name == "sat" else out_name.replace("_", " ").title(),
                    "category": "base",
                    "ext": "webp",
                })
        # DEM (grad_meh wins if ocap didn't supply one)
        if not (world_out / "dem" / "dem.asc.gz").exists():
            dem_src = grad_dir / "dem.asc.gz"
            if dem_src.exists():
                shutil.copy2(dem_src, world_out / "dem" / "dem.asc.gz")
            else:
                dem_raw = grad_dir / "dem.asc"
                if dem_raw.exists():
                    _gz_in_place(dem_raw, world_out / "dem" / "dem.asc.gz")
        # preview
        preview = grad_dir / "preview.png"
        if preview.exists():
            shutil.copy2(preview, world_out / "preview.png")

    grad_meta = _read_grad_meta(grad_dir) if grad_dir else {}

    map_json: dict[str, Any] = {
        "schemaVersion": "ramet-1",
        "worldName": world,
        "displayName": grad_meta.get("displayName", world.title()),
        "worldSize": grad_meta.get("worldSize"),
        "imageSize": grad_meta.get("imageSize") or grad_meta.get("worldSize"),
        "multiplier": grad_meta.get("multiplier", 1.0),
        "cellSize": grad_meta.get("cellSize"),
        "latitude": grad_meta.get("latitude"),
        "longitude": grad_meta.get("longitude"),
        "attribution": "Bohemia Interactive",
        "minZoom": grad_meta.get("minZoom", 0),
        "maxZoom": grad_meta.get("maxZoom", 7),
        "source": "+".join(sources) if sources else "unknown",
        "rasterLayers": raster_layers,
        "preview": "preview.png" if (world_out / "preview.png").exists() else None,
    }
    if (world_out / "dem" / "dem.asc.gz").exists():
        map_json["dem"] = {"asc": "dem/dem.asc.gz", "cellSize": grad_meta.get("cellSize")}
    if svg_layers:
        map_json["svgLayers"] = svg_layers
    return map_json
