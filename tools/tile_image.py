"""Tile a PIL Image into a {z}/{x}/{y}.png pyramid matching grad_meh's writeImagePyramid."""
from __future__ import annotations
import math
from pathlib import Path
from PIL import Image

TILE_SIZE = 256


def write_pyramid(img: Image.Image, out_dir: Path, tile_size: int = TILE_SIZE) -> None:
    """Write a zoom-level tile pyramid. z=0 = smallest overview, z=max = full-res tiles.

    Matches C++ writeImagePyramid: halves resolution each level, stops when both
    dimensions fall below tile_size, tiles each level into tile_size×tile_size PNGs.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    img = img.convert("RGBA")

    # Build levels from full-res downward (mirrors C++ vector construction)
    levels: list[Image.Image] = []
    level_img = img
    while level_img.width >= tile_size or level_img.height >= tile_size or not levels:
        levels.append(level_img)
        nw = max(1, level_img.width // 2)
        nh = max(1, level_img.height // 2)
        if nw == level_img.width and nh == level_img.height:
            break
        level_img = level_img.resize((nw, nh), Image.LANCZOS)

    # levels[0]=full-res=highest z, levels[-1]=smallest=z=0
    for z, img_at_level in enumerate(reversed(levels)):
        lw, lh = img_at_level.size
        cols = math.ceil(lw / tile_size)
        rows = math.ceil(lh / tile_size)

        z_dir = out_dir / str(z)
        z_dir.mkdir(exist_ok=True)

        for x in range(cols):
            x_dir = z_dir / str(x)
            x_dir.mkdir(exist_ok=True)
            for y in range(rows):
                tile = Image.new("RGBA", (tile_size, tile_size), 0)
                left = x * tile_size
                top = y * tile_size
                crop = img_at_level.crop(
                    (left, top, min(left + tile_size, lw), min(top + tile_size, lh))
                )
                tile.paste(crop, (0, 0))
                tile.save(x_dir / f"{y}.png", optimize=False)
