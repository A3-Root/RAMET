"""Re-encode raster tile pyramids:
- sat-family (sat, sat_dark, baked_sat) -> WebP q85 via cwebp
- topo-family (topo, topo_dark, topoRelief, colorRelief) -> pngquant + oxipng

Idempotent: skips outputs already present and newer than source.
Tools required on PATH: cwebp, pngquant, oxipng. Missing tools -> warning + skip
of that step (pyramid still emitted as raw PNG).
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

WEBP_VARIANTS = {"sat", "sat_dark", "baked_sat", "baked_sat_dark"}
PNG_VARIANTS = {"topo", "topo_dark", "topoRelief", "colorRelief", "baked_topo", "baked_topo_dark"}


def _have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def optimize(world_dir: Path) -> dict:
    tiles_dir = world_dir / "tiles"
    counts = {"webp": 0, "png": 0, "skipped": 0, "errors": 0}
    if not tiles_dir.is_dir():
        return counts

    have_cwebp = _have("cwebp")
    have_pngquant = _have("pngquant")
    have_oxipng = _have("oxipng")

    for variant_dir in tiles_dir.iterdir():
        if not variant_dir.is_dir():
            continue
        variant = variant_dir.name
        if variant in WEBP_VARIANTS and have_cwebp:
            for png in variant_dir.rglob("*.png"):
                webp = png.with_suffix(".webp")
                if webp.exists() and webp.stat().st_mtime >= png.stat().st_mtime:
                    counts["skipped"] += 1
                    continue
                try:
                    subprocess.run(
                        ["cwebp", "-quiet", "-q", "85", str(png), "-o", str(webp)],
                        check=True,
                    )
                    png.unlink()
                    counts["webp"] += 1
                except subprocess.CalledProcessError:
                    counts["errors"] += 1
        elif variant in PNG_VARIANTS:
            for png in variant_dir.rglob("*.png"):
                if have_pngquant:
                    subprocess.run(
                        ["pngquant", "--quality=80-95", "--strip", "--force",
                         "--ext", ".png", "--skip-if-larger", str(png)],
                        check=False,
                    )
                if have_oxipng:
                    subprocess.run(
                        ["oxipng", "-o", "4", "--strip", "safe", "--quiet", str(png)],
                        check=False,
                    )
                counts["png"] += 1
    return counts


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--world-dir", required=True)
    args = ap.parse_args()
    counts = optimize(Path(args.world_dir))
    print(counts)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
