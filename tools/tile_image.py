"""Tile a PIL Image into a {z}/{x}/{y} pyramid matching grad_meh's writeImagePyramid."""
from __future__ import annotations
import math
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from PIL import Image

TILE_SIZE = 256
_WORKERS = min(os.cpu_count() or 4, 16)


def _write_tile(
    img_at_level: Image.Image,
    x: int,
    y: int,
    lw: int,
    lh: int,
    x_dir: Path,
    tile_size: int,
    fmt: str,
) -> None:
    left = x * tile_size
    top = y * tile_size
    right = min(left + tile_size, lw)
    bottom = min(top + tile_size, lh)
    crop = img_at_level.crop((left, top, right, bottom))

    if right - left < tile_size or bottom - top < tile_size:
        # Edge tile — pad to full tile size.
        tile = Image.new("RGBA", (tile_size, tile_size), 0)
        tile.paste(crop, (0, 0))
    else:
        tile = crop

    path = x_dir / f"{y}.{fmt}"
    if fmt == "webp":
        tile.save(path, format="WEBP", quality=85, method=2)
    else:
        # compress_level=1: fast write; oxipng re-compresses afterwards anyway.
        tile.save(path, compress_level=1)


def write_pyramid(
    img: Image.Image,
    out_dir: Path,
    tile_size: int = TILE_SIZE,
    fmt: str = "png",
) -> None:
    """Write a zoom-level tile pyramid.

    Matches C++ writeImagePyramid: halves resolution each level, stops when both
    dimensions fall below tile_size, tiles each level into tile_size×tile_size files.

    fmt: "png" (default) or "webp" — format written for every tile.
    Tile writes within each zoom level are parallelised via ThreadPoolExecutor.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    img = img.convert("RGBA")

    levels: list[Image.Image] = []
    level_img = img
    while level_img.width >= tile_size or level_img.height >= tile_size or not levels:
        levels.append(level_img)
        nw = max(1, level_img.width // 2)
        nh = max(1, level_img.height // 2)
        if nw == level_img.width and nh == level_img.height:
            break
        level_img = level_img.resize((nw, nh), Image.LANCZOS)

    with ThreadPoolExecutor(max_workers=_WORKERS) as pool:
        for z, img_at_level in enumerate(reversed(levels)):
            lw, lh = img_at_level.size
            cols = math.ceil(lw / tile_size)
            rows = math.ceil(lh / tile_size)

            z_dir = out_dir / str(z)
            z_dir.mkdir(exist_ok=True)

            futures = []
            for x in range(cols):
                x_dir = z_dir / str(x)
                x_dir.mkdir(exist_ok=True)
                for y in range(rows):
                    futures.append(
                        pool.submit(_write_tile, img_at_level, x, y, lw, lh, x_dir, tile_size, fmt)
                    )
            for f in as_completed(futures):
                f.result()
