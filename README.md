# RAMET

**Root's Arma Map Export Tool** — single source of truth for exporting Arma 3 terrain into planner-ready raster + vector tile sets.

RAMET absorbs two upstream tools (`grad_meh` on Arma main branch, `ocap-renderterrain` on Arma diagnostic branch), drives both with one bulk-export workflow over [Archangel](../ARCHANGEL), post-processes their outputs into a unified `output/{world}/` tree, and ships everything (mods + Docker context + Python tools + batch scripts) as one `hemtt release` bundle. The output drops directly into [JSOC-OPS-Warlords](../JSOC-OPS-Warlords) as the planner's tile source.

## Quick start

1. Build & install
   ```powershell
   # one-time: in each subproject
   cd subprojects\grad_meh             ; hemtt release ; cd ..\..
   cd subprojects\ocap-renderterrain   ; hemtt release ; cd ..\..

   # full bundle
   hemtt release
   ```
   Unzip `releases/{ver}/root_amet-{ver}.zip` into your Arma 3 root. It plants `@root_amet`, `@grad_meh`, `@ocap_renderterrain`, `batch\`, `tools\`, `ramet\`, `ocap_renderterrain\` (Docker context), and `$ARCHANGEL$`.

2. Edit `batch\worlds.txt` (one CfgWorlds class per line) and place it in your Arma 3 root.

3. Run the pipeline
   ```cmd
   batch\99_full_pipeline.bat
   ```
   This chains the four steps below with pauses for the one manual action (Steam branch swap).

## Pipeline at a glance

| Step | Script                          | Branch | What it does                                                                       |
| ---- | ------------------------------- | ------ | ---------------------------------------------------------------------------------- |
| 1    | `batch\01_export_grad_meh.bat`  | main   | `gradMehExportMap` per world; sat + GeoJSON + DEM + preview to `ramet_intermediate\grad_meh\` |
| 2    | `batch\02_export_ocap.bat`      | diag   | `diag_exportTerrainSVG` + ocap exporter per world to `ramet_intermediate\ocap_rt\`  |
| 3    | `batch\03_postprocess.bat`      | —      | Docker render → `tools\orchestrate.py` (merge + PMTiles + SVG slice + WebP/pngquant + verify) |
| 4    | `batch\04_deploy.bat`           | —      | Copy `output\{world}\` into `JSOC-OPS-Warlords\server\warlords\map_tiles\{world}\` |

Inside Arma, both bulk-export missions use Archangel (`"archangel" callExtension ["ramet.bulk.next_world", []]` etc.) to share queue state with the Python `ramet/` module, so the run survives crashes and per-world branch swaps.

## Layout

```
RAMET/
├── .hemtt/hooks/        # pre_build stages subproject releases; post_build bundles everything
├── addons/main/         # @root_amet — XEH, two bulk-export SQF functions
├── modules/$ARCHANGEL$  # marker so Archangel adds `ramet` to sys.path
├── ramet/               # Python module exposed via Archangel (bulk / stage / kickoff)
├── tools/               # Post-processing: orchestrate, slice_svg, geojson_to_pmtiles,
│                        #   merge_outputs, optimize_tiles, verify, deploy_to_planner
├── batch/               # Operator runbook (.bat) + worlds.txt
├── subprojects/         # grad_meh + ocap-renderterrain, verbatim
├── docs/                # SCHEMA.md, BULK_EXPORT.md, INTEGRATION.md
├── output/              # Generated; pushed to planner repo by step 4
└── reference_files/     # Read-only sample data (do not modify)
```

## Dependencies

- Docker Desktop (for ocap-renderterrain render)
- Python 3.11+ with `lxml`, `pyyaml`, `pillow` (`pip install -r tools/requirements.txt`)
- `tippecanoe`, `pmtiles` CLI (PMTiles build) — orchestrate logs a skip if missing
- `cwebp`, `pngquant`, `oxipng` (raster optimization) — skipped per-layer if missing
- Existing subproject toolchains: CMake/Conan/Intercept (grad_meh), Docker (ocap-rt)
- Planner needs `pmtiles.js` + `protomaps-leaflet.js` vendored under `static/lib/`

## Docs

- **`docs/BULK_EXPORT.md`** — full operator runbook (prereqs, troubleshooting, partial-output handling)
- **`docs/SCHEMA.md`** — `map.json` (`ramet-1`) reference
- **`docs/INTEGRATION.md`** — planner-side patches applied by this change set

## Constraints

- `reference_files/` and `.hemtt/project.toml` are not modified by tooling.
- No git commits made by scripts.
- New `map.json` schema is not backward-compatible with the planner's old format; old fields are dropped.
