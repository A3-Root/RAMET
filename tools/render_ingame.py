"""Build a RAMET 'ingame' raster pyramid from a GMS (arma3MapExporter) output.

Input layout (default; can be overridden via RAMET_INGAME_OUTPUT_DIR on the C# side):

    <Arma3>/RAMET_Output/raw/{world}/a3me/
        base.png                # required
        hires.png               # optional (preferred when present)
        index.json              # GMS PackageIndex metadata

The aerial orthographic layer (cherry-picked from upstream GMS v2.2.0) is optional:

    <Arma3>/RAMET_Output/raw/{world}/a3me/
        aerial.png              # optional in-game "satellite" imagery
        index_aerial.json       # GMS PackageIndex metadata for the aerial layer

Output:

    <ramet_out>/{world}/tiles/ingame/{z}/{x}/{y}.png         (-> .webp after optimize)
    <ramet_out>/{world}/tiles/ingame_aerial/{z}/{x}/{y}.png  (-> .webp after optimize)
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from tile_image import write_pyramid
from raster_transform import (
    LayerResult,
    WorldMeta,
    count_tiles,
    output_pixel_size,
    world_to_pixel,
)

Image.MAX_IMAGE_PIXELS = None

_OVERRIDES_DEFAULT = {"worldSizeSource": "grad_meh", "scaleFactor": 1.0}


def _load_overrides(world: str) -> dict:
    p = Path(__file__).resolve().parent / "world_overrides.json"
    if not p.exists():
        return dict(_OVERRIDES_DEFAULT)
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return dict(_OVERRIDES_DEFAULT)
    base = dict(_OVERRIDES_DEFAULT)
    base.update(data.get("_default", {}) or {})
    per = (data.get("worlds", {}) or {}).get(world, {}) or {}
    base.update(per)
    return base


def _pick_source(ingame_dir: Path) -> Path | None:
    hires = ingame_dir / "hires.png"
    base = ingame_dir / "base.png"
    if hires.exists() and hires.stat().st_size > 0:
        return hires
    if base.exists() and base.stat().st_size > 0:
        return base
    return None


def _read_index(ingame_dir: Path, name: str = "index.json") -> dict:
    p = ingame_dir / name
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _render_source(
    ingame_dir: Path,
    src_path: Path,
    index: dict,
    out_tiles: Path,
    world_size: float,
    layer_id: str,
) -> LayerResult:
    """Resample a single GMS source PNG onto the RAMET world grid and write a pyramid.

    Shared by the topographic (`ingame`) and aerial (`ingame_aerial`) layers — both
    obey the same GMS PackageIndex coordinate convention (SizeInMeters / OriginX / OriginY).
    """
    world = ingame_dir.name
    overrides = _load_overrides(world)
    scale = float(overrides.get("scaleFactor", 1.0)) or 1.0

    gms_size_m = float(index.get("SizeInMeters") or world_size)

    # Effective world extent (in metres) covered by the source PNG.
    # `worldSizeSource = grad_meh` (default) means RAMET treats the canonical world size
    # as authoritative; the source is sized to its own GMS extent then resampled in place.
    src_extent_m = gms_size_m * scale if overrides.get("worldSizeSource") == "gms" else gms_size_m

    src = Image.open(src_path).convert("RGBA")
    wm = WorldMeta(world_size_m=float(world_size), src_extent_m=float(src_extent_m))
    out_px = output_pixel_size(wm, source_width_px=src.width)

    # Resize source so 1 source-pixel == `world_size_m / out_px` metres on the output grid.
    target_src_px = max(1, int(round(out_px * (src_extent_m / float(world_size)))))
    if src.width != target_src_px:
        src = src.resize((target_src_px, target_src_px), Image.BILINEAR)

    # Map GMS origin (top-left of source img) to RAMET world coord.
    origin_x = float(index.get("OriginX") or 0.0)
    origin_y = float(index.get("OriginY") or 0.0)
    # GMS OriginY = -worldSize (bottom-left in world coords); the source covers
    # world rect [0, src_extent_m] x [0, src_extent_m] for default a3 maps.
    world_x_left = -origin_x
    world_y_top = origin_y + src_extent_m  # convert from GMS origin convention

    canvas = Image.new("RGBA", (out_px, out_px), (0, 0, 0, 0))
    px_tl, py_tl = world_to_pixel(world_x_left, world_y_top, wm, out_px)
    canvas.paste(src, (int(round(px_tl)), int(round(py_tl))), src)

    target = out_tiles / layer_id
    write_pyramid(canvas, target, fmt="png")

    total, zmin, zmax = count_tiles(target, "png")
    return LayerResult(
        layer_id=layer_id,
        ext="png",
        min_zoom=zmin if zmin is not None else 0,
        max_zoom=zmax if zmax is not None else 0,
        tile_count=total,
    )


def render(ingame_dir: Path, out_tiles: Path, world_size: float) -> LayerResult | None:
    """Build tiles/ingame pyramid. Returns LayerResult or None if input absent."""
    src_path = _pick_source(ingame_dir)
    if src_path is None:
        print(f"[render_ingame] no source under {ingame_dir}")
        return None
    print(f"[render_ingame] using {src_path.name}")
    index = _read_index(ingame_dir, "index.json")
    return _render_source(ingame_dir, src_path, index, out_tiles, world_size, "ingame")


def render_aerial(ingame_dir: Path, out_tiles: Path, world_size: float) -> LayerResult | None:
    """Build tiles/ingame_aerial pyramid from aerial.png. Returns None if absent.

    Old in-game exports without the aerial pass simply skip this layer.
    """
    src_path = ingame_dir / "aerial.png"
    if not (src_path.exists() and src_path.stat().st_size > 0):
        return None
    print(f"[render_ingame] using {src_path.name} (aerial)")
    # Aerial provenance lives in index_aerial.json; fall back to index.json (same Origin/Size).
    index = _read_index(ingame_dir, "index_aerial.json") or _read_index(ingame_dir, "index.json")
    return _render_source(ingame_dir, src_path, index, out_tiles, world_size, "ingame_aerial")
