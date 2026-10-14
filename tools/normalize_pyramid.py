"""Rescale an adopted tile pyramid onto RAMET's canonical power-of-two grid.

ocap-renderterrain renders at its own pixel scale — 1 px/m for a large world —
so a world whose size is not a power of two comes out as a pyramid whose
deepest zoom is a *partial* tile grid: Altis (30720 m) ends at 120x120 tiles of
a 128x128 grid, Napf (20480 m) at 80x80 of 128x128. Every raster RAMET renders
itself lands on `output_pixel_size`, a power of two, and the planner maps the
full 2^z grid onto the world, so an adopted pyramid like that is drawn at
120/128 — or on Napf 80/128 — of its proper size, anchored at the north-west
corner and misaligned with every other layer. Napf's topographic variants were
visibly a different size from its satellite and in-game layers because of it.

This rescales such a pyramid in place so the deepest zoom is a full square and
the layer covers the world exactly like the rest. A pyramid that is already
square is left untouched, so re-running costs one directory listing.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from raster_transform import TILE_SIZE, WorldMeta, resample_source
from tile_image import write_pyramid

Image.MAX_IMAGE_PIXELS = None


def _next_pow2(n: int) -> int:
    p = 1
    while p < n:
        p <<= 1
    return p


def pyramid_extent(layer_dir: Path, ext: str) -> tuple[int, int, int] | None:
    """(deepest zoom, tile columns, tile rows) of a pyramid, or None if empty."""
    if not layer_dir.is_dir():
        return None
    zooms = [int(d.name) for d in layer_dir.iterdir() if d.is_dir() and d.name.isdigit()]
    if not zooms:
        return None
    z = max(zooms)
    zdir = layer_dir / str(z)
    xs = [int(d.name) for d in zdir.iterdir() if d.is_dir() and d.name.isdigit()]
    if not xs:
        return None
    ys: set[int] = set()
    for x in xs:
        for tile in (zdir / str(x)).glob(f"*.{ext}"):
            if tile.stem.isdigit():
                ys.add(int(tile.stem))
    if not ys:
        return None
    return z, max(xs) + 1, max(ys) + 1


def stitch(layer_dir: Path, zoom: int, cols: int, rows: int, ext: str) -> Image.Image:
    """Reassemble one zoom level into a single image."""
    canvas = Image.new("RGBA", (cols * TILE_SIZE, rows * TILE_SIZE), (0, 0, 0, 0))
    zdir = layer_dir / str(zoom)
    for x in range(cols):
        xdir = zdir / str(x)
        if not xdir.is_dir():
            continue
        for y in range(rows):
            tile = xdir / f"{y}.{ext}"
            if not tile.is_file():
                continue
            with Image.open(tile) as im:
                canvas.paste(im.convert("RGBA"), (x * TILE_SIZE, y * TILE_SIZE))
    return canvas


def normalise(layer_dir: Path, ext: str = "png") -> bool:
    """Rescale `layer_dir` onto the power-of-two grid. True if it was rewritten."""
    extent = pyramid_extent(layer_dir, ext)
    if extent is None:
        return False
    zoom, cols, rows = extent
    side = max(cols, rows)
    square = 2 ** zoom
    if cols == square and rows == square:
        return False

    src_px = side * TILE_SIZE
    target_px = _next_pow2(src_px)
    print(f"[normalize_pyramid] {layer_dir.name}: z{zoom} {cols}x{rows} of "
          f"{square}x{square} — rescaling {src_px}px to {target_px}px")
    stitched = stitch(layer_dir, zoom, cols, rows, ext)
    # The stitched image is the whole world, so source extent == world extent and
    # resample_source simply scales it onto the canonical canvas.
    meta = WorldMeta(world_size_m=float(target_px), src_extent_m=float(target_px))
    canvas = resample_source(stitched, meta, target_px)
    del stitched
    write_pyramid(canvas, layer_dir, fmt=ext)
    del canvas
    return True


__all__ = ["normalise", "pyramid_extent", "stitch"]
