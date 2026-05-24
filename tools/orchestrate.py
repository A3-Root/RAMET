"""Top-level post-processing entry point.

Reads upstream exporter outputs directly from the Arma 3 root:
    <Arma3>/grad_meh/{world}/
    <Arma3>/ocap_exporter/{world}/              (raw SVG + ASC)
    <Arma3>/ocap_renderterrain_output/{world}/  (Docker-rendered tile pyramids)

Writes the unified per-world tree to:
    <Arma3>/ramet_output/{world}/

For dev runs (no Arma), pass --from-reference to read inputs out of
RAMET/reference_files/ and write to RAMET/output/.

Usage:
    python tools/orchestrate.py --all
    python tools/orchestrate.py --world altis
    python tools/orchestrate.py --world altis --from-reference
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import merge_outputs  # noqa: E402
import optimize_tiles  # noqa: E402
import verify as verify_mod  # noqa: E402


def _safe_import_pmtiles():
    try:
        import geojson_to_pmtiles
        return geojson_to_pmtiles
    except Exception:
        return None


def _safe_import_slice():
    try:
        import slice_svg
        return slice_svg
    except Exception:
        return None


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


def process_world(world: str,
                  grad_dir: Path | None,
                  ocap_raw_dir: Path | None,
                  ocap_rendered_dir: Path | None,
                  out_root: Path,
                  skip_pmtiles: bool = False,
                  skip_slice: bool = False,
                  skip_optimize: bool = False) -> dict:
    if not any([grad_dir, ocap_raw_dir, ocap_rendered_dir]):
        return {"world": world, "ok": False, "reason": "no inputs"}

    map_json = merge_outputs.merge_world(world, grad_dir, ocap_raw_dir, ocap_rendered_dir, out_root)

    # vector / pmtiles from grad_meh geojsons
    if grad_dir is not None and not skip_pmtiles:
        mod = _safe_import_pmtiles()
        if mod is not None:
            try:
                out_pmtiles = out_root / world / "vector" / "features.pmtiles"
                manifest = mod.build_pmtiles(grad_dir, out_pmtiles,
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
                (out_root / world / "vector" / "classes.json").write_text(
                    json.dumps(map_json["vectorSource"]["layers"], indent=2),
                    encoding="utf-8",
                )
            except Exception as exc:
                print(f"[orchestrate] {world}: pmtiles build skipped — {exc}")

    # svg slicing from raw ocap SVG
    if ocap_raw_dir is not None and not skip_slice:
        mod = _safe_import_slice()
        if mod is not None:
            try:
                svg_in = out_root / world / "svg" / "full.svg.gz"
                if svg_in.exists():
                    results = mod.slice_svg(svg_in, out_root / world / "svg" / "layers")
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
        counts = optimize_tiles.optimize(out_root / world)
        print(f"[orchestrate] {world}: optimize counts={counts}")
        for layer in map_json.get("rasterLayers", []):
            variant = layer["id"]
            sample = (out_root / world / "tiles" / variant / "0" / "0" / "0.webp")
            if sample.exists():
                layer["ext"] = "webp"
                layer["path"] = f"tiles/{variant}/{{z}}/{{x}}/{{y}}.webp"

    (out_root / world / "map.json").write_text(json.dumps(map_json, indent=2), encoding="utf-8")
    (out_root / world / "source.json").write_text(json.dumps({
        "generatedAt": datetime.datetime.utcnow().isoformat() + "Z",
        "grad_meh": str(grad_dir) if grad_dir else None,
        "ocap_raw": str(ocap_raw_dir) if ocap_raw_dir else None,
        "ocap_rendered": str(ocap_rendered_dir) if ocap_rendered_dir else None,
        "tool": "ramet.orchestrate",
    }, indent=2), encoding="utf-8")

    errs, notes = verify_mod.verify_world(out_root / world)
    return {"world": world, "ok": not errs, "errors": errs, "notes": notes}


def _resolve_input_roots(from_reference: bool) -> tuple[Path, Path, Path, Path]:
    """Returns (grad_root, ocap_raw_root, ocap_rendered_root, out_root)."""
    if from_reference:
        ref = ROOT / "reference_files"
        return (ref / "grad_meh",
                ref / "ocap_exporter",
                ref / "ocap_renderterrain_output",
                ROOT / "output")
    # Pipeline mode: env override -> Arma 3 root inferred from cwd.
    arma_root = Path(os.environ.get("RAMET_ARMA_ROOT", os.getcwd()))
    return (arma_root / "grad_meh",
            arma_root / "ocap_exporter",
            arma_root / "ocap_renderterrain_output",
            arma_root / "ramet_output")


def _collect_worlds(roots: tuple[Path, ...]) -> list[str]:
    worlds: set[str] = set()
    for r in roots:
        if r.is_dir():
            for p in r.iterdir():
                if p.is_dir():
                    worlds.add(p.name)
    return sorted(worlds)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="process every world found")
    ap.add_argument("--world", action="append", default=[], help="specific world(s)")
    ap.add_argument("--from-reference", action="store_true",
                    help="read inputs from reference_files/ and write to RAMET/output/")
    ap.add_argument("--output", help="override output root")
    ap.add_argument("--skip-pmtiles", action="store_true")
    ap.add_argument("--skip-slice", action="store_true")
    ap.add_argument("--skip-optimize", action="store_true")
    args = ap.parse_args()

    grad_root, ocap_raw_root, ocap_rendered_root, default_out = _resolve_input_roots(args.from_reference)
    out_root = Path(args.output) if args.output else default_out
    out_root.mkdir(parents=True, exist_ok=True)

    if args.all:
        target = _collect_worlds((grad_root, ocap_raw_root, ocap_rendered_root))
    else:
        target = args.world

    if not target:
        print("no worlds to process — supply --all or --world")
        print(f"  looked in: {grad_root}, {ocap_raw_root}, {ocap_rendered_root}")
        return 2

    results = []
    for w in target:
        gd = grad_root / w if (grad_root / w).is_dir() else None
        oraw = ocap_raw_root / w if (ocap_raw_root / w).is_dir() else None
        orend = ocap_rendered_root / w if (ocap_rendered_root / w).is_dir() else None
        res = process_world(w, gd, oraw, orend, out_root,
                            skip_pmtiles=args.skip_pmtiles,
                            skip_slice=args.skip_slice,
                            skip_optimize=args.skip_optimize)
        results.append(res)
        print(json.dumps(res, indent=2))

    failed = [r for r in results if not r.get("ok")]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
