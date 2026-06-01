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
import time
from concurrent.futures import ProcessPoolExecutor, FIRST_COMPLETED, wait as fut_wait
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import merge_outputs  # noqa: E402
import optimize_tiles  # noqa: E402
import verify as verify_mod  # noqa: E402


def _safe_import_render_sat():
    try:
        import render_sat
        return render_sat
    except Exception:
        return None


def _safe_import_render_topo():
    try:
        import render_topo
        return render_topo
    except Exception:
        return None


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


def _layer_max_zoom(tiles_dir: Path, variant: str, ext: str) -> int | None:
    variant_dir = tiles_dir / variant
    if not variant_dir.is_dir():
        return None
    max_z = -1
    for child in variant_dir.iterdir():
        if child.is_dir() and child.name.isdigit():
            if any(child.rglob(f"*.{ext}")):
                max_z = max(max_z, int(child.name))
    return max_z if max_z >= 0 else None


def _read_dem_cellsize(dem_gz: Path) -> float | None:
    import gzip as _gzip
    try:
        opener = _gzip.open if dem_gz.suffix == ".gz" else open
        with opener(dem_gz, "rt", encoding="utf-8", errors="ignore") as fh:
            for _ in range(10):
                line = fh.readline()
                if line.lower().startswith("cellsize"):
                    return float(line.split()[1])
    except Exception:
        pass
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
                  ingame_dir: Path | None = None,
                  skip_pmtiles: bool = False,
                  skip_slice: bool = False,
                  skip_optimize: bool = False) -> dict:
    if not any([grad_dir, ocap_raw_dir, ocap_rendered_dir, ingame_dir]):
        return {"world": world, "ok": False, "reason": "no inputs"}

    if not any([grad_dir, ocap_raw_dir, ocap_rendered_dir]):
        # ingame-only: preserve existing map.json rather than rebuilding from scratch
        existing = out_root / world / "map.json"
        if not existing.exists():
            return {"world": world, "ok": False, "reason": "no existing map.json — run full pipeline first"}
        map_json = json.loads(existing.read_text(encoding="utf-8"))
        (out_root / world / "tiles").mkdir(parents=True, exist_ok=True)
    else:
        map_json = merge_outputs.merge_world(world, grad_dir, ocap_raw_dir, ocap_rendered_dir, out_root)

    world_size = map_json.get("worldSize") or 0
    out_tiles = out_root / world / "tiles"
    existing_variant_ids = {layer["id"] for layer in map_json.get("rasterLayers", [])}

    stage_results: dict[str, dict] = {}

    def _append_layer_from_result(lr, label_map):
        """Append manifest entry from a LayerResult; honour real ext + zoom."""
        if lr.tile_count == 0:
            print(f"[orchestrate] {world}: dropping zero-tile layer {lr.layer_id}")
            return
        if lr.layer_id in existing_variant_ids:
            return
        ext = lr.ext
        map_json.setdefault("rasterLayers", []).append({
            "id": lr.layer_id,
            "path": f"tiles/{lr.layer_id}/{{z}}/{{x}}/{{y}}.{ext}",
            "label": label_map.get(lr.layer_id, lr.layer_id.replace("_", " ").title()),
            "category": "base",
            "ext": ext,
            "minZoom": lr.min_zoom,
            "maxZoom": lr.max_zoom,
        })
        existing_variant_ids.add(lr.layer_id)

    # --- sat pyramids from grad_meh sat_full.png ---
    if grad_dir is not None:
        sat_full = grad_dir / "sat" / "sat_full.png"
        if world_size:
            mod = _safe_import_render_sat()
            if mod is not None:
                try:
                    written = mod.render(
                        sat_full,
                        grad_dir / "geojson",
                        out_tiles,
                        float(world_size),
                    )
                    _SAT_LABELS = {
                        "sat": "Satellite",
                        "sat_dark": "Satellite Dark",
                        "baked_sat": "Baked Satellite",
                        "baked_sat_dark": "Baked Satellite Dark",
                    }
                    for lr in written:
                        _append_layer_from_result(lr, _SAT_LABELS)
                    stage_results["render_sat"] = {"ok": True, "layers": [lr.layer_id for lr in written]}
                except getattr(mod, "SatSourceMissingError", FileNotFoundError) as exc:
                    print(f"[orchestrate] {world}: render_sat skipped — {exc}")
                    stage_results["render_sat"] = {"ok": False, "reason": "missing", "err": str(exc)}
                except getattr(mod, "SatSourceCorruptError", RuntimeError) as exc:
                    print(f"[orchestrate] {world}: render_sat CORRUPT — {exc}")
                    stage_results["render_sat"] = {"ok": False, "reason": "corrupt", "err": str(exc)}
                except Exception as exc:
                    print(f"[orchestrate] {world}: render_sat failed — {exc}")
                    stage_results["render_sat"] = {"ok": False, "reason": "error", "err": str(exc)}
        else:
            print(f"[orchestrate] {world}: worldSize missing, skipping render_sat")

    # --- topo pyramids from grad_meh dem.asc.gz ---
    if grad_dir is not None:
        dem_path = grad_dir / "dem.asc.gz"
        if not dem_path.exists():
            dem_path = grad_dir / "dem.asc"
        if dem_path.exists() and world_size:
            mod = _safe_import_render_topo()
            if mod is not None:
                try:
                    written = mod.render(
                        dem_path,
                        grad_dir / "geojson",
                        out_tiles,
                        float(world_size),
                    )
                    _TOPO_LABELS = {
                        "topo": "Topographic",
                        "topo_dark": "Topographic Dark",
                        "baked_topo": "Baked Topographic",
                        "baked_topo_dark": "Baked Topographic Dark",
                    }
                    for lr in written:
                        _append_layer_from_result(lr, _TOPO_LABELS)
                    stage_results["render_topo"] = {"ok": True, "layers": [lr.layer_id for lr in written]}
                except Exception as exc:
                    print(f"[orchestrate] {world}: render_topo failed — {exc}")
                    stage_results["render_topo"] = {"ok": False, "reason": "error", "err": str(exc)}

    # --- ingame pyramid from ramet_ingame_output ---
    ingame_root = ingame_dir if (ingame_dir and ingame_dir.is_dir()) else None
    if ingame_root and world_size:
        try:
            import render_ingame  # type: ignore
            lr = render_ingame.render(ingame_root, out_tiles, float(world_size))
            if lr is not None:
                _append_layer_from_result(lr, {"ingame": "In-Game"})
                stage_results["render_ingame"] = {"ok": True}
            else:
                stage_results["render_ingame"] = {"ok": False, "reason": "no source"}
        except Exception as exc:
            print(f"[orchestrate] {world}: render_ingame skipped — {exc}")
            stage_results["render_ingame"] = {"ok": False, "reason": "error", "err": str(exc)}

    # vector / pmtiles from grad_meh geojsons
    if grad_dir is not None and not skip_pmtiles:
        mod = _safe_import_pmtiles()
        if mod is not None:
            try:
                out_pmtiles = out_root / world / "vector" / "features.pmtiles"
                manifest = mod.build_pmtiles(
                                             grad_dir, out_pmtiles,
                                             max_zoom=map_json.get("maxZoom", 14),
                                             min_zoom=map_json.get("minZoom", 0),
                                             anchor_lat=map_json.get("latitude"),
                                             anchor_lon=map_json.get("longitude"),
                                             world_size=map_json.get("worldSize"),
                                         )
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

    # per-layer actual min/maxZoom + drop zero-tile / missing layers
    from raster_transform import count_tiles as _count_tiles
    kept: list[dict] = []
    for layer in map_json.get("rasterLayers", []):
        vid = layer["id"]
        ext = layer.get("ext", "png")
        total, zmin, zmax = _count_tiles(out_tiles / vid, ext)
        if total == 0:
            # Try alternate ext (optimize may have flipped png -> webp).
            alt = "webp" if ext == "png" else "png"
            total, zmin, zmax = _count_tiles(out_tiles / vid, alt)
            if total > 0:
                ext = alt
                layer["ext"] = ext
                layer["path"] = f"tiles/{vid}/{{z}}/{{x}}/{{y}}.{ext}"
        if total == 0:
            print(f"[orchestrate] {world}: drop layer {vid} — zero tiles on disk")
            continue
        if zmin is not None:
            layer["minZoom"] = zmin
        if zmax is not None:
            layer["maxZoom"] = zmax
        kept.append(layer)
    map_json["rasterLayers"] = kept
    layer_zooms = [l["maxZoom"] for l in kept if "maxZoom" in l]
    if layer_zooms:
        map_json["maxZoom"] = max(layer_zooms)
        canonical_px = 256 * (2 ** map_json["maxZoom"])
        map_json["imageSize"] = canonical_px
        if world_size:
            map_json["multiplier"] = canonical_px / float(world_size)
    layer_mins = [l["minZoom"] for l in kept if "minZoom" in l]
    if layer_mins:
        map_json["minZoom"] = min(layer_mins)

    # cellSize from DEM ASC header if meta.json didn't supply it
    if not map_json.get("cellSize"):
        cs = _read_dem_cellsize(out_root / world / "dem" / "dem.asc.gz")
        if cs is not None:
            map_json["cellSize"] = cs
            if isinstance(map_json.get("dem"), dict):
                map_json["dem"]["cellSize"] = cs

    (out_root / world / "map.json").write_text(json.dumps(map_json, indent=2), encoding="utf-8")
    (out_root / world / "source.json").write_text(json.dumps({
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
        "grad_meh": str(grad_dir) if grad_dir else None,
        "ocap_raw": str(ocap_raw_dir) if ocap_raw_dir else None,
        "ocap_rendered": str(ocap_rendered_dir) if ocap_rendered_dir else None,
        "tool": "ramet.orchestrate",
    }, indent=2), encoding="utf-8")

    errs, notes = verify_mod.verify_world(out_root / world)
    return {"world": world, "ok": not errs, "errors": errs, "notes": notes, "stages": stage_results}


def _resolve_input_roots(from_reference: bool) -> tuple[Path, Path, Path, Path, Path]:
    """Returns (grad_root, ocap_raw_root, ocap_rendered_root, ingame_root, out_root)."""
    if from_reference:
        ref = ROOT / "reference_files"
        return (ref / "grad_meh",
                ref / "ocap_exporter",
                ref / "ocap_renderterrain_output",
                ref / "ramet_ingame_output",
                ROOT / "output")
    # Pipeline mode: env override -> Arma 3 root inferred from cwd.
    arma_root = Path(os.environ.get("RAMET_ARMA_ROOT", os.getcwd()))
    return (arma_root / "grad_meh",
            arma_root / "ocap_exporter",
            arma_root / "ocap_renderterrain_output",
            arma_root / "ramet_ingame_output",
            arma_root / "ramet_output")


def _collect_worlds(roots: tuple[Path, ...]) -> list[str]:
    worlds: set[str] = set()
    for r in roots:
        if r.is_dir():
            for p in r.iterdir():
                if p.is_dir():
                    worlds.add(p.name)
    return sorted(worlds)


def _check_pause(pause_file: Path) -> None:
    """Block until pause_file is removed, printing a one-time notice."""
    if pause_file.exists():
        print(f"[orchestrate] PAUSED — remove {pause_file} (or run resume_postprocess.bat) to continue", flush=True)
        while pause_file.exists():
            time.sleep(5)
        print("[orchestrate] RESUMED", flush=True)


def _run_world(args_tuple: tuple) -> dict:
    world, gd, oraw, orend, ingame, out_root, skip_pmtiles, skip_slice, skip_optimize = args_tuple
    try:
        return process_world(world, gd, oraw, orend, out_root, ingame, skip_pmtiles, skip_slice, skip_optimize)
    except Exception as exc:
        return {"world": world, "ok": False, "errors": [str(exc)], "notes": []}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="process every world found")
    ap.add_argument("--world", action="append", default=[], help="specific world(s)")
    ap.add_argument("--from-reference", action="store_true",
                    help="read inputs from reference_files/ and write to RAMET/output/")
    ap.add_argument("--output", help="override output root")
    ap.add_argument("--ingame-only", action="store_true",
                    help="process only ramet_ingame_output; skip grad_meh/ocap stages")
    ap.add_argument("--skip-pmtiles", action="store_true")
    ap.add_argument("--skip-slice", action="store_true")
    ap.add_argument("--skip-optimize", action="store_true")
    ap.add_argument("--workers", type=int, default=3,
                    help="parallel world workers (default 2; peak ~12 GB RAM per worker — do not exceed floor(RAM_GB/12))")
    args = ap.parse_args()

    grad_root, ocap_raw_root, ocap_rendered_root, ingame_root, default_out = _resolve_input_roots(args.from_reference)
    out_root = Path(args.output) if args.output else default_out
    out_root.mkdir(parents=True, exist_ok=True)

    skip_pmtiles = args.skip_pmtiles or args.ingame_only
    skip_slice = args.skip_slice or args.ingame_only
    skip_optimize = args.skip_optimize or args.ingame_only

    if args.all:
        target = _collect_worlds((grad_root, ocap_raw_root, ocap_rendered_root, ingame_root))
    else:
        target = args.world

    if not target:
        print("no worlds to process — supply --all or --world")
        print(f"  looked in: {grad_root}, {ocap_raw_root}, {ocap_rendered_root}, {ingame_root}")
        return 2

    world_args = [
        (w,
         None if args.ingame_only else (grad_root / w if (grad_root / w).is_dir() else None),
         None if args.ingame_only else (ocap_raw_root / w if (ocap_raw_root / w).is_dir() else None),
         None if args.ingame_only else (ocap_rendered_root / w if (ocap_rendered_root / w).is_dir() else None),
         ingame_root / w if (ingame_root / w).is_dir() else None,
         out_root, skip_pmtiles, skip_slice, skip_optimize)
        for w in target
    ]

    # Pause sentinel: create <Arma3>/ramet.pause on the host to pause between worlds.
    pause_file = out_root.parent / "ramet.pause"

    results = []
    if args.workers == 1 or len(world_args) == 1:
        for wa in world_args:
            _check_pause(pause_file)
            res = _run_world(wa)
            results.append(res)
            print(json.dumps(res, indent=2))
    else:
        queue = list(world_args)
        pending: dict = {}

        with ProcessPoolExecutor(max_workers=args.workers) as pool:
            # Fill pool to capacity respecting pause.
            def _fill():
                while queue and len(pending) < args.workers:
                    _check_pause(pause_file)
                    wa = queue.pop(0)
                    fut = pool.submit(_run_world, wa)
                    pending[fut] = wa[0]

            _fill()
            while pending:
                done, _ = fut_wait(pending.keys(), return_when=FIRST_COMPLETED)
                for fut in done:
                    pending.pop(fut)
                    res = fut.result()
                    results.append(res)
                    print(json.dumps(res, indent=2), flush=True)
                _fill()

    failed = [r for r in results if not r.get("ok")]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
