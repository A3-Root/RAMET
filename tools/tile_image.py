"""Tile a PIL Image into a {z}/{x}/{y} pyramid matching grad_meh's writeImagePyramid."""
from __future__ import annotations
import gc
import math
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from PIL import Image

import ramet_log

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
    # NB: convert("RGBA") on an already-RGBA image returns a *full copy* (= a
    # second 17 GB allocation for a 65536² world). Only convert when needed.
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    # Pre-compute the level sizes (full-res first) without materialising the
    # images, so we can generate + tile + free one level at a time. This keeps
    # at most two adjacent levels alive (full + its half) instead of the whole
    # pyramid (~1.33× the full image) resident simultaneously.
    sizes: list[tuple[int, int]] = []
    lw, lh = img.size
    first = True
    while lw >= tile_size or lh >= tile_size or first:
        first = False
        sizes.append((lw, lh))
        nw = max(1, lw // 2)
        nh = max(1, lh // 2)
        if nw == lw and nh == lh:
            break
        lw, lh = nw, nh

    n_levels = len(sizes)
    cur = img  # full resolution = highest z (= n_levels - 1)

    with ThreadPoolExecutor(max_workers=_WORKERS) as pool:
        for i, (lw, lh) in enumerate(sizes):
            z = n_levels - 1 - i
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
                        pool.submit(_write_tile, cur, x, y, lw, lh, x_dir, tile_size, fmt)
                    )
            for f in as_completed(futures):
                f.result()

            # Downsample to the next (smaller) level, then free this one.
            if i + 1 < n_levels:
                nxt = cur.resize(sizes[i + 1], Image.LANCZOS)
                if cur is not img:
                    cur.close()
                del cur
                gc.collect()
                cur = nxt

    if cur is not img:
        cur.close()
    gc.collect()
    ramet_log.trim()  # return the freed downsample buffers to the OS
