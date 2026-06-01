"""Generate topo tile pyramids from dem.asc.gz, replicating grad_meh's topo rendering.

Reads:
  dem_path          (dem.asc or dem.asc.gz)
  geojson_dir/      (for baked overlays)

Writes:
  out_tiles_dir/topo/           (only if not already present — ocap wins on conflict)
  out_tiles_dir/topo_dark/      (only if not already present)
  out_tiles_dir/baked_topo/     (always — new variant not produced by ocap)
  out_tiles_dir/baked_topo_dark/

Color logic replicates C++ buildTopoPixels + topoColor from topoimages.cpp.
"""
from __future__ import annotations
import gc
import gzip
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from tile_image import write_pyramid
from raster_transform import (
    LayerResult,
    WorldMeta,
    count_tiles,
    output_pixel_size,
)

Image.MAX_IMAGE_PIXELS = None

# Baked overlay style: (fill_rgb, fill_alpha, outline_rgb_or_None, outline_alpha)
_STYLE_LIGHT = {
    "rivers":     (( 96, 158, 190), 0.68, ( 65, 124, 158), 0.45),
    "buildings":  ((130, 124, 112), 0.32, ( 86,  82,  76), 0.45),
    "roads":      ((216, 205, 184), 0.48, None,             0.0),
    "powerlines": (( 94,  94,  94), 0.42, None,             0.0),
}
_STYLE_DARK = {
    "rivers":     (( 58, 122, 156), 0.62, ( 84, 154, 190), 0.45),
    "buildings":  ((126, 118,  98), 0.28, (178, 168, 140), 0.38),
    "roads":      ((190, 180, 158), 0.42, None,             0.0),
    "powerlines": ((154, 158, 164), 0.42, None,             0.0),
}


def _read_dem(path: Path) -> tuple[np.ndarray, dict]:
    """Parse ASC grid. Returns (elevation[nrows, ncols], header)."""
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="ascii") as f:
        lines = f.read().splitlines()

    header: dict[str, float] = {}
    data_start = 0
    hdr_keys = {"ncols", "nrows", "xllcorner", "yllcorner", "cellsize", "nodata_value"}
    for i, line in enumerate(lines):
        parts = line.strip().split()
        if len(parts) == 2 and parts[0].lower() in hdr_keys:
            header[parts[0].lower()] = float(parts[1])
            data_start = i + 1
        elif header:
            break

    ncols = int(header["ncols"])
    nrows = int(header["nrows"])
    nodata = header.get("nodata_value", -9999.0)

    values: list[float] = []
    for line in lines[data_start:]:
        values.extend(float(v) for v in line.strip().split() if v)

    arr = np.array(values, dtype=np.float32).reshape(nrows, ncols)
    arr[arr == nodata] = 0.0
    return arr, header


def _build_topo(elevation: np.ndarray, cellsize: float, dark: bool = False) -> Image.Image:
    """Replicate C++ buildTopoPixels + topoColor per-pixel in numpy.

    The C++ computes shade from elevation differences over 2m horizontal spans.
    At DEM resolution (1 pixel = cellsize metres) we normalise the gradient
    back to metres so that hillshade intensity matches the C++ output.
    """
    h, w = elevation.shape

    # Central-difference gradient in world metres
    dx_raw = np.zeros_like(elevation)
    dx_raw[:, 1:-1] = elevation[:, 2:] - elevation[:, :-2]
    dx_raw[:, 0]    = elevation[:, 1]  - elevation[:, 0]
    dx_raw[:, -1]   = elevation[:, -1] - elevation[:, -2]

    # ASC rows are top-to-bottom (row 0 = max worldY = north).
    # C++: dy = elev(worldY+1) - elev(worldY-1)  (positive = terrain rises north)
    # In the DEM array: higher worldY = lower row index, so:
    dy_raw = np.zeros_like(elevation)
    dy_raw[1:-1, :] = elevation[:-2, :] - elevation[2:, :]
    dy_raw[0, :]    = elevation[0, :]   - elevation[1, :]
    dy_raw[-1, :]   = elevation[-2, :]  - elevation[-1, :]

    # Normalise: C++ difference spans 2×1 m; each DEM step spans cellsize m
    norm = 1.0 / cellsize
    dx = dx_raw * norm
    dy = dy_raw * norm

    shade = np.clip((-dx * 0.55 + dy * 0.35) / 32.0, -0.55, 0.55)
    normalized = np.clip((elevation + 20.0) / 520.0, 0.0, 1.0)

    # Contour lines (50 m interval, 1.4 m width)
    contour_rem = np.abs(np.mod(elevation, 50.0))
    contour = (elevation > 1.0) & (
        (contour_rem < 1.4) | (contour_rem > 50.0 - 1.4)
    )

    # Per-dark colour ramps
    if dark:
        land_low   = np.array([ 42.0,  58.0,  46.0], dtype=np.float32)
        land_high  = np.array([ 92.0,  86.0,  70.0], dtype=np.float32)
        water_low  = np.array([ 19.0,  42.0,  58.0], dtype=np.float32)
        water_high = np.array([ 32.0,  66.0,  88.0], dtype=np.float32)
        base_shade, shade_min, shade_max, contour_factor = 0.86, 0.68, 1.38, 1.34
    else:
        land_low   = np.array([190.0, 212.0, 179.0], dtype=np.float32)
        land_high  = np.array([238.0, 231.0, 208.0], dtype=np.float32)
        water_low  = np.array([132.0, 176.0, 199.0], dtype=np.float32)
        water_high = np.array([168.0, 202.0, 218.0], dtype=np.float32)
        base_shade, shade_min, shade_max, contour_factor = 0.72, 0.55, 1.18, 0.62

    is_water = (elevation < 0.5)

    # Shade factor (h×w)
    sf_base = np.clip(base_shade + shade * 0.42, shade_min, shade_max)
    sf = sf_base * np.where(contour, contour_factor, 1.0)

    # Interpolate land / water colours, then apply shade
    n3 = normalized[:, :, np.newaxis]   # (h, w, 1)
    sf3 = sf[:, :, np.newaxis]          # (h, w, 1)
    is_w3 = is_water[:, :, np.newaxis]  # (h, w, 1)

    land  = (land_low  + (land_high  - land_low)  * n3) * sf3
    water = (water_low + (water_high - water_low) * n3) * sf3
    rgb = np.where(is_w3, water, land)

    out = np.empty((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    out[..., 3] = 255
    return Image.fromarray(out, "RGBA")


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
        print(f"[render_topo] warn: {path.name}: {exc}")
    return []


# Horizontal strip height (rows) for in-place overlay baking — see render_sat.
_BAKE_STRIP_ROWS = 4096


def _w2px(
    coord: list[float], world_size: float, img_w: int, img_h: int, y_offset: int = 0
) -> tuple[int, int]:
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
    out_rgba: tuple | None,
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
                    if out_rgba:
                        draw.line(pts + [pts[0]], fill=out_rgba, width=1)
        elif gtype == "MultiPolygon":
            for poly in coords:
                for ring in poly:
                    pts = [_w2px(c, world_size, img_w, img_h, y_offset) for c in ring]
                    if len(pts) >= 3:
                        draw.polygon(pts, fill=fill_rgba)
                        if out_rgba:
                            draw.line(pts + [pts[0]], fill=out_rgba, width=1)


def _overlay_layers(geojson_dir: Path, style: dict) -> list[tuple]:
    """Ordered draw list (features, fill_rgba, outline_rgba, line_width); empties dropped."""
    order = ["rivers", "buildings", "roads", "powerlines"]
    sources = {
        "rivers":     [geojson_dir / "river.geojson.gz"],
        "buildings":  [geojson_dir / "house.geojson.gz"],
        "roads":      sorted((geojson_dir / "roads").glob("*.geojson.gz"))
                      if (geojson_dir / "roads").is_dir() else [],
        "powerlines": [geojson_dir / "powerline.geojson.gz"],
    }
    layers: list[tuple] = []
    for key in order:
        fill, fa, out, oa = style[key]
        lw = 1 if key == "powerlines" else 2
        fill_rgba = fill + (int(fa * 255),)
        out_rgba = (out + (int(oa * 255),)) if out else None
        for path in sources[key]:
            feats = _load_gz(path)
            if feats:
                layers.append((feats, fill_rgba, out_rgba, lw))
    return layers


def _bake_overlays_inplace(
    base: Image.Image,
    geojson_dir: Path,
    world_size: float,
    style: dict,
) -> Image.Image:
    """Composite overlays onto `base` IN PLACE in horizontal strips (peak = base +
    a few small strips instead of 4× full). Mutates and returns `base`."""
    layers = _overlay_layers(geojson_dir, style)
    if not layers:
        return base
    w, h = base.size
    for y0 in range(0, h, _BAKE_STRIP_ROWS):
        y1 = min(y0 + _BAKE_STRIP_ROWS, h)
        ovl = Image.new("RGBA", (w, y1 - y0), (0, 0, 0, 0))
        draw = ImageDraw.Draw(ovl)
        for feats, fill_rgba, out_rgba, lw in layers:
            _draw_features(draw, feats, world_size, w, h,
                           fill_rgba, out_rgba, lw, y_offset=y0)
        strip = base.crop((0, y0, w, y1))
        merged = Image.alpha_composite(strip, ovl)
        base.paste(merged, (0, y0))
        del ovl, draw, strip, merged
    gc.collect()
    return base


def _emit(layer_id: str, target: Path, ext: str = "png") -> LayerResult:
    total, zmin, zmax = count_tiles(target, ext)
    return LayerResult(
        layer_id=layer_id,
        ext=ext,
        min_zoom=zmin if zmin is not None else 0,
        max_zoom=zmax if zmax is not None else 0,
        tile_count=total,
    )


def render(
    dem_path: Path,
    geojson_dir: Path,
    out_tiles: Path,
    world_size: float,
) -> list[LayerResult]:
    """Generate topo pyramids from DEM. Returns per-layer LayerResult list.

    topo / topo_dark are skipped if their output dirs already exist (ocap wins).
    baked_topo / baked_topo_dark are always generated.
    """
    if not dem_path.exists():
        print(f"[render_topo] {dem_path} not found, skipping")
        return []

    print(f"[render_topo] reading DEM {dem_path.name}")
    elevation, header = _read_dem(dem_path)
    cellsize = float(header.get("cellsize", 1.0))
    h, w = elevation.shape
    print(f"[render_topo] DEM {w}×{h}, cellsize={cellsize}m")

    results: list[LayerResult] = []

    plain_variants = [("topo", False), ("topo_dark", True)]
    topo_img: Image.Image | None = None
    topo_dark_img: Image.Image | None = None

    for variant_id, is_dark in plain_variants:
        target = out_tiles / variant_id
        if target.exists():
            print(f"[render_topo] {variant_id} already present, skipping (ocap wins)")
            continue
        print(f"[render_topo] generating {variant_id}")
        img = _build_topo(elevation, cellsize, dark=is_dark)
        write_pyramid(img, target)
        results.append(_emit(variant_id, target))
        if variant_id == "topo":
            topo_img = img
        else:
            topo_dark_img = img

    if not geojson_dir.is_dir():
        print(f"[render_topo] no geojson dir at {geojson_dir}, skipping baked variants")
        return results

    if topo_img is None:
        print("[render_topo] generating topo base for baked overlay")
        topo_img = _build_topo(elevation, cellsize, dark=False)
    if topo_dark_img is None:
        print("[render_topo] generating topo_dark base for baked overlay")
        topo_dark_img = _build_topo(elevation, cellsize, dark=True)

    # Resize DEM-rendered base to the authoritative pyramid size derived from worldSize.
    wm = WorldMeta(world_size_m=float(world_size), src_extent_m=float(world_size))
    out_px = output_pixel_size(wm, source_width_px=max(topo_img.width, int(world_size)))
    if topo_img.width != out_px:
        print(f"[render_topo] upscaling topo base {topo_img.width}px -> {out_px}px")
        topo_img = topo_img.resize((out_px, out_px), Image.LANCZOS)
    if topo_dark_img.width != out_px:
        topo_dark_img = topo_dark_img.resize((out_px, out_px), Image.LANCZOS)

    print("[render_topo] generating baked_topo")
    _bake_overlays_inplace(topo_img, geojson_dir, world_size, _STYLE_LIGHT)
    write_pyramid(topo_img, out_tiles / "baked_topo")
    results.append(_emit("baked_topo", out_tiles / "baked_topo"))
    del topo_img
    gc.collect()

    print("[render_topo] generating baked_topo_dark")
    _bake_overlays_inplace(topo_dark_img, geojson_dir, world_size, _STYLE_DARK)
    write_pyramid(topo_dark_img, out_tiles / "baked_topo_dark")
    results.append(_emit("baked_topo_dark", out_tiles / "baked_topo_dark"))
    del topo_dark_img
    gc.collect()

    return results
