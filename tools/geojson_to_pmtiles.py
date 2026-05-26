"""Bundle every grad_meh GeoJSON for one world into a single PMTiles file.

Pipeline: gunzip each .geojson.gz into a temp file, hand them all to tippecanoe
(`--layer=<class>` per input), then convert the resulting .mbtiles to .pmtiles
via the `pmtiles` CLI.

tippecanoe and pmtiles CLIs must be on PATH. On Windows we recommend running
the operation inside the same Docker image used by ocap-renderterrain
post-processing — see batch/03_postprocess.bat.
"""

from __future__ import annotations

import argparse
import gzip
import json
import math
import shutil
import subprocess
import tempfile
from pathlib import Path

DEFAULT_MAX_ZOOM = 14
DEFAULT_MIN_ZOOM = 0


def _gunzip_to(src: Path, dst: Path) -> None:
    with gzip.open(src, "rb") as fp_in, dst.open("wb") as fp_out:
        shutil.copyfileobj(fp_in, fp_out)


def _normalize_geojson(path: Path) -> None:
    """Wrap a plain JSON array as a FeatureCollection in-place."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return
    if isinstance(data, list):
        path.write_text(
            json.dumps({"type": "FeatureCollection", "features": data}),
            encoding="utf-8",
        )


def _has_features(geojson_path: Path) -> bool:
    try:
        data = json.loads(geojson_path.read_text(encoding="utf-8"))
    except Exception:
        return False
    if isinstance(data, list):
        return bool(data)
    if isinstance(data, dict):
        return bool(data.get("features"))
    return False


def _reproject_coords(
    coords: list,
    anchor_lat: float,
    anchor_lon: float,
    half_size: float,
    cos_lat: float,
) -> list:
    """Recursively convert Arma 3 meter coords to WGS84 degrees.

    Arma 3 origin (0,0) is bottom-left; center is (worldSize/2, worldSize/2).
    """
    if not coords:
        return coords
    if isinstance(coords[0], (int, float)):
        x, y = coords[0], coords[1]
        lon = anchor_lon + (x - half_size) / (111320.0 * cos_lat)
        lat = anchor_lat + (y - half_size) / 111320.0
        return [lon, lat] + list(coords[2:])
    return [_reproject_coords(c, anchor_lat, anchor_lon, half_size, cos_lat) for c in coords]


def _reproject_geojson(
    path: Path,
    anchor_lat: float,
    anchor_lon: float,
    world_size: float,
) -> None:
    """Transform all coordinates in a GeoJSON file from Arma 3 CRS to WGS84 in-place."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return

    half_size = world_size / 2.0
    cos_lat = math.cos(math.radians(anchor_lat)) or 1e-10

    def _transform(geom: dict | None) -> None:
        if not geom:
            return
        t = geom.get("type", "")
        if t in ("Point", "LineString", "MultiPoint", "Polygon",
                 "MultiLineString", "MultiPolygon"):
            geom["coordinates"] = _reproject_coords(
                geom["coordinates"], anchor_lat, anchor_lon, half_size, cos_lat
            )
        elif t == "GeometryCollection":
            for g in geom.get("geometries", []):
                _transform(g)

    features = data if isinstance(data, list) else data.get("features", [])
    for feat in features:
        if isinstance(feat, dict):
            _transform(feat.get("geometry"))

    path.write_text(json.dumps(data), encoding="utf-8")


def build_pmtiles(
    grad_meh_world_dir: Path,
    out_pmtiles: Path,
    max_zoom: int = DEFAULT_MAX_ZOOM,
    min_zoom: int = DEFAULT_MIN_ZOOM,
    anchor_lat: float | None = None,
    anchor_lon: float | None = None,
    world_size: float | None = None,
) -> dict:
    """Build PMTiles from every *.geojson(.gz) under `grad_meh_world_dir`.

    Pass anchor_lat, anchor_lon, world_size to reproject Arma 3 meter
    coordinates to WGS84 before handing to tippecanoe.

    Returns a manifest dict listing layers actually included.
    """
    if shutil.which("tippecanoe") is None:
        raise RuntimeError("tippecanoe not found on PATH")
    if shutil.which("pmtiles") is None:
        raise RuntimeError("pmtiles CLI not found on PATH")

    reproject = (
        anchor_lat is not None
        and anchor_lon is not None
        and world_size is not None
        and world_size > 0
    )

    out_pmtiles.parent.mkdir(parents=True, exist_ok=True)

    layers: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="ramet_pmtiles_") as tmpd:
        tmp = Path(tmpd)
        tippe_args: list[str] = [
            "tippecanoe",
            "-o", str(tmp / "out.mbtiles"),
            "-zg",
            "--maximum-zoom", str(max_zoom),
            "--minimum-zoom", str(min_zoom),
            "--drop-densest-as-needed",
            "--no-feature-limit",
            "--no-tile-size-limit",
            "--read-parallel",
            "--no-progress-indicator",
            "--force",
        ]

        for src in sorted(grad_meh_world_dir.rglob("*.geojson*")):
            name = src.name
            if name.endswith(".geojson.gz"):
                stem = name[:-len(".geojson.gz")]
                staged = tmp / f"{stem}.geojson"
                _gunzip_to(src, staged)
            elif name.endswith(".geojson"):
                stem = name[:-len(".geojson")]
                staged = tmp / name
                shutil.copy2(src, staged)
            else:
                continue

            _normalize_geojson(staged)
            if reproject:
                _reproject_geojson(staged, anchor_lat, anchor_lon, world_size)
            if not _has_features(staged):
                continue
            tippe_args += ["-L", f"{stem}:{staged}"]
            layers.append({"id": stem, "label": stem.replace("_", " ").title()})

        if not layers:
            raise RuntimeError(f"no GeoJSON features found under {grad_meh_world_dir}")

        subprocess.run(tippe_args, check=True)
        # mbtiles -> pmtiles
        subprocess.run(
            ["pmtiles", "convert", str(tmp / "out.mbtiles"), str(out_pmtiles)],
            check=True,
        )

    return {"pmtiles": str(out_pmtiles), "layers": layers}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True, help="grad_meh world dir")
    ap.add_argument("--out", dest="out", required=True, help="output .pmtiles path")
    ap.add_argument("--max-zoom", type=int, default=DEFAULT_MAX_ZOOM)
    ap.add_argument("--min-zoom", type=int, default=DEFAULT_MIN_ZOOM)
    ap.add_argument("--anchor-lat", type=float, default=None, help="map center latitude (WGS84)")
    ap.add_argument("--anchor-lon", type=float, default=None, help="map center longitude (WGS84)")
    ap.add_argument("--world-size", type=float, default=None, help="world size in metres")
    args = ap.parse_args()
    manifest = build_pmtiles(
        Path(args.src), Path(args.out),
        max_zoom=args.max_zoom, min_zoom=args.min_zoom,
        anchor_lat=args.anchor_lat, anchor_lon=args.anchor_lon,
        world_size=args.world_size,
    )
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
