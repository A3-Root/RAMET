"""Single source of truth for RAMET world<->pixel transforms.

Used by render_sat, render_topo, render_ingame so every raster lands on the
same authoritative output pixel grid for a given world.

Conventions
-----------
* Arma world origin: bottom-left, +Y north, +X east, in metres.
* Raster pixel origin: top-left, +x east, +y south.
* `worldSize` is metres on each side of the (square) world.
* Output pyramid uses TILE_SIZE=256 (matches tile_image.write_pyramid).
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from PIL import Image

TILE_SIZE = 256
# Disable PIL decompression-bomb guard globally: our sat sources are trusted.
Image.MAX_IMAGE_PIXELS = None


@dataclass(frozen=True)
class WorldMeta:
    world_size_m: float
    # Optional: extents of the source raster in world metres (defaults: full world).
    src_extent_m: float | None = None


def _next_pow2(n: int) -> int:
    if n <= 1:
        return 1
    p = 1
    while p < n:
        p <<= 1
    return p


def output_pixel_size(world_meta: WorldMeta, source_width_px: int | None = None) -> int:
    """Authoritative output dim (W=H) for the pyramid.

    Rule: round up `worldSize_m * pixels_per_meter` to next power-of-two so
    the pyramid bottoms out cleanly at TILE_SIZE.  pixels_per_meter is derived
    from the source raster width if provided; else 1.0 px/m floored at 4096.
    """
    if source_width_px and source_width_px > 0 and world_meta.src_extent_m:
        ppm = source_width_px / float(world_meta.src_extent_m)
        target = int(world_meta.world_size_m * ppm)
    elif source_width_px and source_width_px > 0:
        target = source_width_px
    else:
        target = max(4096, int(world_meta.world_size_m))
    return _next_pow2(max(TILE_SIZE, target))


def world_to_pixel(x_m: float, y_m: float, world_meta: WorldMeta, out_px: int) -> tuple[float, float]:
    """Arma world metres -> output raster pixels (top-left origin)."""
    scale = out_px / float(world_meta.world_size_m)
    px = x_m * scale
    py = (world_meta.world_size_m - y_m) * scale
    return (px, py)


def resample_source(
    src_img: Image.Image,
    world_meta: WorldMeta,
    out_px: int,
    *,
    resample: int | None = None,
    pad_rgba: tuple = (0, 0, 0, 0),
) -> Image.Image:
    """Resample / pad `src_img` into the authoritative (out_px x out_px) RGBA canvas.

    If src extent covers less than the full world, the source is placed at the
    correct world position and padded with `pad_rgba` — never stretched.
    """
    if resample is None:
        resample = Image.BILINEAR
    src_extent = world_meta.src_extent_m or world_meta.world_size_m
    if src_extent <= 0:
        src_extent = world_meta.world_size_m

    scaled_w = max(1, int(round(out_px * (src_extent / world_meta.world_size_m))))
    scaled_h = scaled_w

    src_rgba = src_img if src_img.mode == "RGBA" else src_img.convert("RGBA")
    if src_rgba.size != (scaled_w, scaled_h):
        src_rgba = src_rgba.resize((scaled_w, scaled_h), resample)

    if (scaled_w, scaled_h) == (out_px, out_px):
        return src_rgba

    canvas = Image.new("RGBA", (out_px, out_px), pad_rgba)
    # Source is assumed centred on (0,0)..(src_extent,src_extent) in world coords;
    # paste at top-left in raster terms (world y_max corner).
    offset_x = 0
    offset_y = out_px - scaled_h
    canvas.paste(src_rgba, (offset_x, offset_y), src_rgba)
    return canvas


def max_pyramid_zoom(out_px: int) -> int:
    """Deepest zoom level emitted by write_pyramid for an out_px x out_px image."""
    n = out_px
    z = 0
    while n > TILE_SIZE:
        n >>= 1
        z += 1
    return z


@dataclass
class LayerResult:
    """Returned by render_*.render() so orchestrate can build the manifest
    without re-scanning the filesystem for extension/zoom info."""
    layer_id: str
    ext: str
    min_zoom: int
    max_zoom: int
    tile_count: int


def count_tiles(layer_dir: Path, ext: str) -> tuple[int, int | None, int | None]:
    """Walk a layer pyramid dir. Returns (total_tiles, min_zoom_with_tiles, max_zoom_with_tiles)."""
    if not layer_dir.is_dir():
        return (0, None, None)
    total = 0
    z_min: int | None = None
    z_max: int | None = None
    for child in layer_dir.iterdir():
        if not (child.is_dir() and child.name.isdigit()):
            continue
        n = sum(1 for _ in child.rglob(f"*.{ext}"))
        if n == 0:
            continue
        total += n
        z = int(child.name)
        z_min = z if z_min is None else min(z_min, z)
        z_max = z if z_max is None else max(z_max, z)
    return (total, z_min, z_max)


__all__ = [
    "TILE_SIZE",
    "WorldMeta",
    "LayerResult",
    "output_pixel_size",
    "world_to_pixel",
    "resample_source",
    "max_pyramid_zoom",
    "count_tiles",
]
