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
import shutil
import subprocess
import tempfile
from pathlib import Path

DEFAULT_MAX_ZOOM = 14
DEFAULT_MIN_ZOOM = 0


def _gunzip_to(src: Path, dst: Path) -> None:
    with gzip.open(src, "rb") as fp_in, dst.open("wb") as fp_out:
        shutil.copyfileobj(fp_in, fp_out)


def _has_features(geojson_path: Path) -> bool:
    try:
        data = json.loads(geojson_path.read_text(encoding="utf-8"))
    except Exception:
        return False
    feats = data.get("features") if isinstance(data, dict) else None
    return bool(feats)


def build_pmtiles(grad_meh_world_dir: Path, out_pmtiles: Path,
                  max_zoom: int = DEFAULT_MAX_ZOOM,
                  min_zoom: int = DEFAULT_MIN_ZOOM) -> dict:
    """Build PMTiles from every *.geojson(.gz) under `grad_meh_world_dir`.

    Returns a manifest dict listing layers actually included.
    """
    if shutil.which("tippecanoe") is None:
        raise RuntimeError("tippecanoe not found on PATH")
    if shutil.which("pmtiles") is None:
        raise RuntimeError("pmtiles CLI not found on PATH")

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
    args = ap.parse_args()
    manifest = build_pmtiles(Path(args.src), Path(args.out),
                             max_zoom=args.max_zoom, min_zoom=args.min_zoom)
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
