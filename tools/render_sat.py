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


def _w2px(coord: list[float], world_size: float, img_w: int, img_h: int) -> tuple[int, int]:
    return (
        int(coord[0] / world_size * img_w),
        int(img_h - coord[1] / world_size * img_h),
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
) -> None:
    for feat in features:
        geom = feat.get("geometry") or {}
        gtype = geom.get("type", "")
        coords = geom.get("coordinates")
        if not coords:
            continue
        if gtype == "LineString":
            pts = [_w2px(c, world_size, img_w, img_h) for c in coords]
            if len(pts) >= 2:
                draw.line(pts, fill=fill_rgba, width=line_width)
        elif gtype == "MultiLineString":
            for seg in coords:
                pts = [_w2px(c, world_size, img_w, img_h) for c in seg]
                if len(pts) >= 2:
                    draw.line(pts, fill=fill_rgba, width=line_width)
        elif gtype == "Polygon":
            for ring in coords:
                pts = [_w2px(c, world_size, img_w, img_h) for c in ring]
                if len(pts) >= 3:
                    draw.polygon(pts, fill=fill_rgba)
                    if outline_rgba:
                        draw.line(pts + [pts[0]], fill=outline_rgba, width=1)
        elif gtype == "MultiPolygon":
            for poly in coords:
                for ring in poly:
                    pts = [_w2px(c, world_size, img_w, img_h) for c in ring]
                    if len(pts) >= 3:
                        draw.polygon(pts, fill=fill_rgba)
                        if outline_rgba:
                            draw.line(pts + [pts[0]], fill=outline_rgba, width=1)


def _composite_layer(
    base: Image.Image,
    features: list[dict],
    world_size: float,
    fill_rgb: tuple,
    fill_alpha: float,
    outline_rgb: tuple | None,
    outline_alpha: float,
    line_width: int = 2,
) -> Image.Image:
    if not features:
        return base
    w, h = base.size
    ovl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ovl)
    fa = int(fill_alpha * 255)
    oa = int(outline_alpha * 255)
    _draw_features(
        draw, features, world_size, w, h,
        fill_rgb + (fa,),
        (outline_rgb + (oa,)) if outline_rgb else None,
        line_width,
    )
    return Image.alpha_composite(base, ovl)


def _apply_baked_overlays(
    base: Image.Image,
    geojson_dir: Path,
    world_size: float,
    style: dict,
) -> Image.Image:
    # base is always RGBA here; skip the copy — alpha_composite returns a new
    # image on each call so the caller's reference to base is not mutated.
    result = base

    # Rivers first (background feature)
    fill, fa, out, oa = style["rivers"]
    result = _composite_layer(
        result, _load_gz(geojson_dir / "river.geojson.gz"),
        world_size, fill, fa, out, oa,
    )

    # Buildings
    fill, fa, out, oa = style["buildings"]
    result = _composite_layer(
        result, _load_gz(geojson_dir / "house.geojson.gz"),
        world_size, fill, fa, out, oa,
    )

    # Roads (all types)
    fill, fa, out, oa = style["roads"]
    roads_dir = geojson_dir / "roads"
    if roads_dir.is_dir():
        for road_file in sorted(roads_dir.glob("*.geojson.gz")):
            result = _composite_layer(
                result, _load_gz(road_file), world_size, fill, fa, None, 0.0,
            )

    # Powerlines
    fill, fa, out, oa = style["powerlines"]
    result = _composite_layer(
        result, _load_gz(geojson_dir / "powerline.geojson.gz"),
        world_size, fill, fa, None, 0.0, line_width=1,
    )

    return result


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
    """
    validate_sat_source(sat_full)

    print(f"[render_sat] loading {sat_full.name} ({sat_full.stat().st_size // 1024 // 1024} MB)")
    sat_raw = Image.open(sat_full).convert("RGBA")
    print(f"[render_sat] image {sat_raw.width}×{sat_raw.height}")

    wm = WorldMeta(world_size_m=float(world_size), src_extent_m=float(world_size))
    out_px = output_pixel_size(wm, source_width_px=sat_raw.width)
    if (sat_raw.width, sat_raw.height) != (out_px, out_px):
        print(f"[render_sat] resampling source -> authoritative {out_px}x{out_px}")
        sat = resample_source(sat_raw, wm, out_px, resample=Image.BILINEAR)
        del sat_raw
    else:
        sat = sat_raw

    results: list[LayerResult] = []

    print("[render_sat] tiling sat")
    write_pyramid(sat, out_tiles / "sat", fmt="webp")
    results.append(_emit("sat", out_tiles / "sat"))

    print("[render_sat] generating sat_dark")
    dark = _make_dark(sat)
    write_pyramid(dark, out_tiles / "sat_dark", fmt="webp")
    results.append(_emit("sat_dark", out_tiles / "sat_dark"))

    if geojson_dir.is_dir():
        print("[render_sat] generating baked_sat")
        baked = _apply_baked_overlays(sat, geojson_dir, world_size, _STYLE_LIGHT)
        # Release sat now — baked_sat_dark only needs dark, not sat.
        del sat
        gc.collect()
        write_pyramid(baked, out_tiles / "baked_sat", fmt="webp")
        results.append(_emit("baked_sat", out_tiles / "baked_sat"))
        del baked
        gc.collect()

        print("[render_sat] generating baked_sat_dark")
        baked_dark = _apply_baked_overlays(dark, geojson_dir, world_size, _STYLE_DARK)
        del dark
        gc.collect()
        write_pyramid(baked_dark, out_tiles / "baked_sat_dark", fmt="webp")
        results.append(_emit("baked_sat_dark", out_tiles / "baked_sat_dark"))
        del baked_dark
        gc.collect()
    else:
        print(f"[render_sat] no geojson dir at {geojson_dir}, skipping baked variants")
        del sat, dark
        gc.collect()

    return results
