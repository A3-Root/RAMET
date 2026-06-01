"""Generate sat tile pyramid and variants from sat_full.png exported by grad_meh.

Reads:
  grad_dir/sat/sat_full.png
  grad_dir/meta.json          (for worldSize)
  grad_dir/geojson/           (for baked overlays)

Writes:
  out_tiles_dir/sat/
  out_tiles_dir/sat_dark/
  out_tiles_dir/baked_sat/
  out_tiles_dir/baked_sat_dark/
"""
from __future__ import annotations
import gc
import gzip
import json
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, UnidentifiedImageError

from tile_image import write_pyramid
from raster_transform import (
    LayerResult,
    WorldMeta,
    count_tiles,
    output_pixel_size,
    resample_source,
)
import ramet_log

# Disable PIL decompression-bomb guard: sat exports from grad_meh are trusted.
Image.MAX_IMAGE_PIXELS = None


class SatSourceMissingError(FileNotFoundError):
    """Sat source PNG missing or zero-byte."""


class SatSourceCorruptError(RuntimeError):
    """Sat source PNG present but unreadable / zero-sized after decode."""


def validate_sat_source(path: Path) -> None:
    """Fail fast with a distinct exception class per failure mode."""
    if path is None or not path.exists():
        raise SatSourceMissingError(f"sat source missing: {path}")
    size = path.stat().st_size
    if size == 0:
        raise SatSourceMissingError(f"sat source zero-byte: {path}")
    try:
        with Image.open(path) as probe:
            probe.verify()
    except UnidentifiedImageError as exc:
        raise SatSourceCorruptError(f"sat source unidentified: {path} ({exc})") from exc
    except Exception as exc:
        raise SatSourceCorruptError(f"sat source verify failed: {path} ({exc})") from exc
    # Reopen for a real load probe (verify() leaves the file in an unloadable state).
    try:
        with Image.open(path) as probe2:
            w, h = probe2.size
    except Exception as exc:
        raise SatSourceCorruptError(f"sat source size probe failed: {path} ({exc})") from exc
    if w <= 0 or h <= 0:
        raise SatSourceCorruptError(f"sat source has zero dimension: {path} ({w}x{h})")

# Overlay style: (fill_rgb, fill_alpha, outline_rgb_or_None, outline_alpha)
_STYLE_LIGHT = {
    "buildings":  ((238, 226, 202), 0.42, (116, 106,  92), 0.56),
    "roads":      ((245, 236, 212), 0.58, None,             0.0),
    "powerlines": (( 60,  60,  60), 0.48, None,             0.0),
    "rivers":     (( 86, 158, 206), 0.52, ( 42, 110, 160), 0.46),
}
_STYLE_DARK = {
    "buildings":  ((160, 150, 128), 0.34, (218, 204, 170), 0.52),
    "roads":      ((210, 202, 184), 0.52, None,             0.0),
    "powerlines": ((176, 182, 190), 0.48, None,             0.0),
    "rivers":     (( 62, 134, 178), 0.46, ( 96, 176, 218), 0.46),
}


def _load_gz(path: Path) -> list[dict]:
    if not path.exists():
        return []
    try:
        with gzip.open(path, "rt", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return data.get("features", []) or []
    except Exception as exc:
        print(f"[render_sat] warn: {path.name}: {exc}")
    return []


def _w2px(
    coord: list[float], world_size: float, img_w: int, img_h: int, y_offset: int = 0
) -> tuple[int, int]:
    # img_w/img_h are the FULL image dims (world->pixel mapping). y_offset shifts
    # the result into strip-local coordinates when baking in horizontal strips.
    return (
        int(coord[0] / world_size * img_w),
        int(img_h - coord[1] / world_size * img_h) - y_offset,
    )


def _draw_features(
    draw: ImageDraw.Draw,
    features: list[dict],
    world_size: float,
    img_w: int,
    img_h: int,
    fill_rgba: tuple,
    outline_rgba: tuple | None,
    line_width: int,
    y_offset: int = 0,
) -> None:
    for feat in features:
        geom = feat.get("geometry") or {}
        gtype = geom.get("type", "")
        coords = geom.get("coordinates")
        if not coords:
            continue
        if gtype == "LineString":
            pts = [_w2px(c, world_size, img_w, img_h, y_offset) for c in coords]
            if len(pts) >= 2:
                draw.line(pts, fill=fill_rgba, width=line_width)
        elif gtype == "MultiLineString":
            for seg in coords:
                pts = [_w2px(c, world_size, img_w, img_h, y_offset) for c in seg]
                if len(pts) >= 2:
                    draw.line(pts, fill=fill_rgba, width=line_width)
        elif gtype == "Polygon":
            for ring in coords:
                pts = [_w2px(c, world_size, img_w, img_h, y_offset) for c in ring]
                if len(pts) >= 3:
                    draw.polygon(pts, fill=fill_rgba)
                    if outline_rgba:
                        draw.line(pts + [pts[0]], fill=outline_rgba, width=1)
        elif gtype == "MultiPolygon":
            for poly in coords:
                for ring in poly:
                    pts = [_w2px(c, world_size, img_w, img_h, y_offset) for c in ring]
                    if len(pts) >= 3:
                        draw.polygon(pts, fill=fill_rgba)
                        if outline_rgba:
                            draw.line(pts + [pts[0]], fill=outline_rgba, width=1)


# Horizontal strip height (rows) used when baking overlays in place. A full-size
# overlay layer for a 65536² world would be another 17 GB RGBA image; baking in
# strips keeps the transient overhead to ~3 strips (≈3 GB at 4096 rows) on top of
# the base image, instead of the old 4× peak (base + overlay + alpha_composite
# result, all full-size, while the caller still held the original).
_BAKE_STRIP_ROWS = 4096


def _overlay_layers(geojson_dir: Path, style: dict) -> list[tuple]:
    """Build the ordered draw list: (features, fill_rgba, outline_rgba, line_width).

    Order matches the historical baking order: rivers, buildings, roads, powerlines.
    Empty layers are dropped.
    """
    layers: list[tuple] = []

    def _rgba(rgb: tuple, alpha: float) -> tuple:
        return rgb + (int(alpha * 255),)

    fill, fa, out, oa = style["rivers"]
    layers.append((_load_gz(geojson_dir / "river.geojson.gz"),
                   _rgba(fill, fa), _rgba(out, oa) if out else None, 2))

    fill, fa, out, oa = style["buildings"]
    layers.append((_load_gz(geojson_dir / "house.geojson.gz"),
                   _rgba(fill, fa), _rgba(out, oa) if out else None, 2))

    fill, fa, out, oa = style["roads"]
    roads_dir = geojson_dir / "roads"
    if roads_dir.is_dir():
        for road_file in sorted(roads_dir.glob("*.geojson.gz")):
            layers.append((_load_gz(road_file), _rgba(fill, fa), None, 2))

    fill, fa, out, oa = style["powerlines"]
    layers.append((_load_gz(geojson_dir / "powerline.geojson.gz"),
                   _rgba(fill, fa), None, 1))

    return [lyr for lyr in layers if lyr[0]]


def _bake_overlays_inplace(
    base: Image.Image,
    geojson_dir: Path,
    world_size: float,
    style: dict,
) -> Image.Image:
    """Composite all vector overlays onto `base` IN PLACE, processing horizontal
    strips so peak memory stays at base + ~3 small strips rather than 4× full.

    `base` (RGBA) is mutated and also returned for convenience. Features are
    re-iterated per strip; PIL clips off-strip geometry (drawn at negative /
    out-of-range y via the strip y_offset), so the result is identical to a
    single full-image composite.
    """
    layers = _overlay_layers(geojson_dir, style)
    if not layers:
        return base
    w, h = base.size
    for y0 in range(0, h, _BAKE_STRIP_ROWS):
        y1 = min(y0 + _BAKE_STRIP_ROWS, h)
        ovl = Image.new("RGBA", (w, y1 - y0), (0, 0, 0, 0))
        draw = ImageDraw.Draw(ovl)
        for features, fill_rgba, outline_rgba, lw in layers:
            _draw_features(draw, features, world_size, w, h,
                           fill_rgba, outline_rgba, lw, y_offset=y0)
        strip = base.crop((0, y0, w, y1))
        merged = Image.alpha_composite(strip, ovl)
        base.paste(merged, (0, y0))
        del ovl, draw, strip, merged
    gc.collect()
    return base


_DARK_STRIP_ROWS = 256


def _make_dark(sat: Image.Image) -> Image.Image:
    """Replicate C++ makeDarkSatellitePixels: luminance-based dark tint.

    Processes in horizontal strips to avoid allocating a full float32 copy of
    the entire image (which would be 4× the raw RGBA size — e.g. 16 GB for a
    32768-px sat).  Each strip is ~256 rows × width × 4ch × 4 bytes ≈ 128 MB
    at most, keeping peak overhead well under 1 GB regardless of world size.
    """
    w, h = sat.size
    out_img = Image.new("RGBA", (w, h))
    for y0 in range(0, h, _DARK_STRIP_ROWS):
        y1 = min(y0 + _DARK_STRIP_ROWS, h)
        strip = sat.crop((0, y0, w, y1))
        arr = np.asarray(strip, dtype=np.float32)  # strip is already RGBA
        lum = arr[..., 0] * 0.2126 + arr[..., 1] * 0.7152 + arr[..., 2] * 0.0722
        out = np.empty((y1 - y0, w, 4), dtype=np.uint8)
        out[..., 0] = np.clip(lum * 0.18 + 18.0, 0, 255)
        out[..., 1] = np.clip(lum * 0.20 + 22.0, 0, 255)
        out[..., 2] = np.clip(lum * 0.24 + 28.0, 0, 255)
        out[..., 3] = 255
        out_img.paste(Image.fromarray(out, "RGBA"), (0, y0))
        del strip, arr, lum, out
    return out_img


def _emit(layer_id: str, target: Path, ext: str = "webp") -> LayerResult:
    total, zmin, zmax = count_tiles(target, ext)
    return LayerResult(
        layer_id=layer_id,
        ext=ext,
        min_zoom=zmin if zmin is not None else 0,
        max_zoom=zmax if zmax is not None else 0,
        tile_count=total,
    )


def render(sat_full: Path, geojson_dir: Path, out_tiles: Path, world_size: float) -> list[LayerResult]:
    """Generate sat pyramids. Returns per-layer results (id, ext, zoom range, tile count).

    Raises SatSourceMissingError / SatSourceCorruptError on bad input — caller decides
    whether to swallow (and mark world partial) or re-raise.

    Operation order is chosen to minimise peak RSS:
      tile sat → dark = make_dark(sat) → tile sat_dark
        → bake light overlays INTO sat (in place) → tile baked_sat → free sat
        → bake dark overlays INTO dark (in place) → tile baked_sat_dark → free dark
    Overlays are baked in place strip-by-strip (_bake_overlays_inplace), so the
    only large images ever simultaneously live are sat + dark (2× out_px²×4),
    plus a few small overlay strips. For a 65536-px world that is ~34 GB + minor
    overhead, comfortably under a 48 GB budget (was ~64 GB with the old 4× path).
    """
    validate_sat_source(sat_full)

    t0 = time.monotonic()
    ramet_log.log(f"[render_sat] loading {sat_full.name} ({sat_full.stat().st_size // 1024 // 1024} MB)")
    sat_raw = Image.open(sat_full).convert("RGBA")
    ramet_log.log(f"[render_sat] image {sat_raw.width}×{sat_raw.height}")

    wm = WorldMeta(world_size_m=float(world_size), src_extent_m=float(world_size))
    out_px = output_pixel_size(wm, source_width_px=sat_raw.width)
    if (sat_raw.width, sat_raw.height) != (out_px, out_px):
        ramet_log.log(f"[render_sat] resampling source -> authoritative {out_px}x{out_px}")
        sat = resample_source(sat_raw, wm, out_px, resample=Image.BILINEAR)
        del sat_raw
        gc.collect()
    else:
        sat = sat_raw

    results: list[LayerResult] = []

    # Step 1: tile plain sat (only sat alive)
    ramet_log.log("[render_sat] tiling sat")
    write_pyramid(sat, out_tiles / "sat", fmt="webp")
    results.append(_emit("sat", out_tiles / "sat"))

    if geojson_dir.is_dir():
        # Step 2: derive dark from pristine sat (strip-based → +1× full)
        ramet_log.log("[render_sat] generating sat_dark")
        dark = _make_dark(sat)            # sat + dark live (2×)

        # Step 3: tile plain sat_dark
        write_pyramid(dark, out_tiles / "sat_dark", fmt="webp")
        results.append(_emit("sat_dark", out_tiles / "sat_dark"))

        # Step 4: bake light overlays INTO sat in place → baked_sat
        ramet_log.log("[render_sat] generating baked_sat")
        _bake_overlays_inplace(sat, geojson_dir, world_size, _STYLE_LIGHT)
        write_pyramid(sat, out_tiles / "baked_sat", fmt="webp")
        results.append(_emit("baked_sat", out_tiles / "baked_sat"))
        del sat
        gc.collect()

        # Step 5: bake dark overlays INTO dark in place → baked_sat_dark
        ramet_log.log("[render_sat] generating baked_sat_dark")
        _bake_overlays_inplace(dark, geojson_dir, world_size, _STYLE_DARK)
        write_pyramid(dark, out_tiles / "baked_sat_dark", fmt="webp")
        results.append(_emit("baked_sat_dark", out_tiles / "baked_sat_dark"))
        del dark
        gc.collect()
    else:
        ramet_log.log(f"[render_sat] no geojson dir at {geojson_dir}, skipping baked variants")
        ramet_log.log("[render_sat] generating sat_dark")
        dark = _make_dark(sat)
        del sat
        gc.collect()
        write_pyramid(dark, out_tiles / "sat_dark", fmt="webp")
        results.append(_emit("sat_dark", out_tiles / "sat_dark"))
        del dark
        gc.collect()

    ramet_log.log(
        f"[render_sat] done in {time.monotonic() - t0:.1f}s peak={ramet_log.peak_mb()}MB"
    )
    return results
