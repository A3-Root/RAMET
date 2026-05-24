"""Top-level post-processing entry point.

For each world found under _intermediate/, produce a unified
output/{world}/ tree:
  1. merge_outputs.merge_world    -> base map.json + raster pyramids + DEM
  2. geojson_to_pmtiles.build_pmtiles  -> vector/features.pmtiles + vector layers
  3. slice_svg.slice_svg            -> svg/layers/*.svg.gz + svg layers
  4. optimize_tiles.optimize        -> webp + pngquant + oxipng
  5. verify.verify_world            -> sanity check; print errors

Then writes map.json + source.json.

Usage:
    python tools/orchestrate.py --all
    python tools/orchestrate.py --world altis
    python tools/orchestrate.py --world altis --from-reference  # use reference_files/
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import merge_outputs  # noqa: E402
import optimize_tiles  # noqa: E402
import verify as verify_mod  # noqa: E402


def _safe_import_pmtiles():
    try:
        import geojson_to_pmtiles  # noqa: E402
        return geojson_to_pmtiles
    except Exception:
        return None


def _safe_import_slice():
    try:
        import slice_svg  # noqa: E402
        return slice_svg
    except Exception:
        return None


def process_world(world: str, intermediate: Path, output: Path,
                  skip_pmtiles: bool = False,
                  skip_slice: bool = False,
                  skip_optimize: bool = False) -> dict:
    grad_dir = intermediate / "grad_meh" / world
    ocap_dir = intermediate / "ocap_rt" / world
    grad = grad_dir if grad_dir.is_dir() else None
    ocap = ocap_dir if ocap_dir.is_dir() else None

    if grad is None and ocap is None:
        return {"world": world, "ok": False, "reason": "no inputs under _intermediate/"}

    map_json = merge_outputs.merge_world(world, grad, ocap, output)

    # vector / pmtiles
    if grad is not None and not skip_pmtiles:
        mod = _safe_import_pmtiles()
        if mod is not None:
            try:
                out_pmtiles = output / world / "vector" / "features.pmtiles"
                manifest = mod.build_pmtiles(grad, out_pmtiles,
                                             max_zoom=map_json.get("maxZoom", 14),
                                             min_zoom=map_json.get("minZoom", 0))
                map_json["vectorSource"] = {
                    "type": "pmtiles",
                    "url": "vector/features.pmtiles",
                    "layers": [
                        {"id": lyr["id"],
                         "label": lyr["label"],
                         "category": _category_for(lyr["id"]),
                         "default": _default_for(lyr["id"])}
                        for lyr in manifest["layers"]
                    ],
                }
                # classes.json companion
                (output / world / "vector" / "classes.json").write_text(
                    json.dumps(map_json["vectorSource"]["layers"], indent=2),
                    encoding="utf-8",
                )
            except Exception as exc:
                print(f"[orchestrate] {world}: pmtiles build skipped — {exc}")

    # svg slicing
    if ocap is not None and not skip_slice:
        mod = _safe_import_slice()
        if mod is not None:
            try:
                svg_in = output / world / "svg" / "full.svg.gz"
                if svg_in.exists():
                    results = mod.slice_svg(svg_in, output / world / "svg" / "layers")
                    map_json["svgLayers"] = [
                        {"id": f"{cls}_svg",
                         "path": f"svg/layers/{cls}.svg.gz",
                         "label": meta["label"]}
                        for cls, meta in results.items()
                    ]
            except Exception as exc:
                print(f"[orchestrate] {world}: svg slice skipped — {exc}")

    # raster optimization
    if not skip_optimize:
        counts = optimize_tiles.optimize(output / world)
        print(f"[orchestrate] {world}: optimize counts={counts}")
        # rewrite raster layer extensions to .webp where we converted
        for layer in map_json.get("rasterLayers", []):
            variant = layer["id"]
            sample = (output / world / "tiles" / variant / "0" / "0" / "0.webp")
            if sample.exists():
                layer["ext"] = "webp"
                layer["path"] = f"tiles/{variant}/{{z}}/{{x}}/{{y}}.webp"

    # finalise manifest
    (output / world / "map.json").write_text(json.dumps(map_json, indent=2), encoding="utf-8")
    (output / world / "source.json").write_text(json.dumps({
        "generatedAt": datetime.datetime.utcnow().isoformat() + "Z",
        "grad_meh": str(grad) if grad else None,
        "ocap_rt": str(ocap) if ocap else None,
        "tool": "ramet.orchestrate",
    }, indent=2), encoding="utf-8")

    errs, notes = verify_mod.verify_world(output / world)
    return {"world": world, "ok": not errs, "errors": errs, "notes": notes}


_TRANSPORT = {"road_main", "road", "track", "trail", "railway"}
_STRUCTURE = {"house", "building", "ruin", "fortress", "powerline", "fence", "wall"}
_TERRAIN = {"forest", "rocks", "water", "rivers", "scrub", "tree"}
_LABELS = {"location"}


def _category_for(lid: str) -> str:
    if any(t in lid for t in _TRANSPORT):
        return "transport"
    if any(t in lid for t in _STRUCTURE):
        return "structure"
    if any(t in lid for t in _TERRAIN):
        return "terrain"
    if any(t in lid for t in _LABELS):
        return "labels"
    return "other"


def _default_for(lid: str) -> bool:
    return any(t in lid for t in {"road_main", "road", "forest", "location", "water"})


def _resolve_intermediate(from_reference: bool) -> Path:
    if from_reference:
        return ROOT / "reference_files"
    # in-game: <Arma3>/ramet_intermediate. dev/post-process: <RAMET>/_intermediate
    candidates = [
        ROOT / "_intermediate",
        ROOT.parent / "ramet_intermediate",
    ]
    for c in candidates:
        if c.is_dir():
            return c
    return ROOT / "_intermediate"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="process every world found")
    ap.add_argument("--world", action="append", default=[], help="specific world(s)")
    ap.add_argument("--from-reference", action="store_true",
                    help="read inputs from reference_files/ instead of _intermediate/")
    ap.add_argument("--output", default=str(ROOT / "output"))
    ap.add_argument("--skip-pmtiles", action="store_true")
    ap.add_argument("--skip-slice", action="store_true")
    ap.add_argument("--skip-optimize", action="store_true")
    args = ap.parse_args()

    intermediate = _resolve_intermediate(args.from_reference)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)

    if args.all:
        worlds: set[str] = set()
        for sub in ("grad_meh", "ocap_rt"):
            for p in (intermediate / sub).glob("*"):
                if p.is_dir():
                    worlds.add(p.name)
        target = sorted(worlds)
    else:
        target = args.world

    if not target:
        print("no worlds to process — supply --all or --world")
        return 2

    results = []
    for w in target:
        res = process_world(
            w, intermediate, output,
            skip_pmtiles=args.skip_pmtiles,
            skip_slice=args.skip_slice,
            skip_optimize=args.skip_optimize,
        )
        results.append(res)
        print(json.dumps(res, indent=2))

    failed = [r for r in results if not r.get("ok")]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
