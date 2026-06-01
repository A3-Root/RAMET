"""Re-encode raster tile pyramids:
- sat-family (sat, sat_dark, baked_sat, baked_sat_dark) -> WebP q85 via cwebp
- topo-family (topo, topo_dark, topoRelief, colorRelief) -> pngquant + oxipng

Idempotent: skips outputs already present and newer than source.
Tools required on PATH: cwebp, pngquant, oxipng. Missing tools -> warning + skip
of that step (pyramid still emitted as raw PNG).
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

WEBP_VARIANTS = {"sat", "sat_dark", "baked_sat", "baked_sat_dark"}
PNG_VARIANTS = {"topo", "topo_dark", "topoRelief", "colorRelief", "baked_topo", "baked_topo_dark"}

_WORKERS = min(os.cpu_count() or 4, 4)


def _have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def _to_webp(png: Path) -> str:
    webp = png.with_suffix(".webp")
    if webp.exists() and webp.stat().st_mtime >= png.stat().st_mtime:
        return "skipped"
    try:
        subprocess.run(
            ["cwebp", "-quiet", "-q", "85", str(png), "-o", str(webp)],
            check=True, capture_output=True,
        )
        png.unlink()
        return "webp"
    except subprocess.CalledProcessError:
        return "error"


def _to_png(png: Path, have_pngquant: bool, have_oxipng: bool) -> str:
    if have_pngquant:
        subprocess.run(
            ["pngquant", "--quality=80-95", "--strip", "--force",
             "--ext", ".png", "--skip-if-larger", str(png)],
            check=False, capture_output=True,
        )
    if have_oxipng:
        subprocess.run(
            ["oxipng", "-o", "4", "--strip", "safe", "--quiet", str(png)],
            check=False, capture_output=True,
        )
    return "png"


def optimize(world_dir: Path, max_workers: int | None = None) -> dict:
    tiles_dir = world_dir / "tiles"
    counts = {"webp": 0, "png": 0, "skipped": 0, "errors": 0}
    if not tiles_dir.is_dir():
        return counts

    have_cwebp    = _have("cwebp")
    have_pngquant = _have("pngquant")
    have_oxipng   = _have("oxipng")

    workers = max_workers if max_workers is not None else _WORKERS
    futures = {}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for variant_dir in tiles_dir.iterdir():
            if not variant_dir.is_dir():
                continue
            variant = variant_dir.name
            pngs = list(variant_dir.rglob("*.png"))
            total = len(pngs)
            if total == 0:
                continue
            print(f"[optimize] {variant}: queuing {total} tiles", flush=True)

            if variant in WEBP_VARIANTS and have_cwebp:
                for png in pngs:
                    futures[pool.submit(_to_webp, png)] = variant
            elif variant in PNG_VARIANTS:
                for png in pngs:
                    futures[pool.submit(_to_png, png, have_pngquant, have_oxipng)] = variant

        done = 0
        report_every = max(1, len(futures) // 20)
        for fut in as_completed(futures):
            result = fut.result()
            counts[result if result in counts else "errors"] += 1
            done += 1
            if done % report_every == 0 or done == len(futures):
                print(f"[optimize] {done}/{len(futures)} tiles done "
                      f"(webp={counts['webp']} png={counts['png']} "
                      f"skip={counts['skipped']} err={counts['errors']})",
                      flush=True)

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
