# RAMET

**Root's Arma Map Export Tool** — single source of truth for exporting Arma 3 terrain into planner-ready raster + vector tile sets.

RAMET absorbs two upstream tools (`grad_meh` on Arma main branch, `ocap-renderterrain` on Arma diagnostic branch), drives both with one bulk-export workflow over [Archangel](../ARCHANGEL), post-processes their outputs into a unified `output/{world}/` tree, and ships everything (mods + Docker context + Python tools + batch scripts) as one `hemtt release` bundle. The output drops directly into [JSOC-OPS-Warlords](../JSOC-OPS-Warlords) as the planner's tile source.

## Quick start

1. Build & install
   ```powershell
   .\release.ps1
   ```
   (Skip the subproject builds with `-SkipSubprojects` once they're already built. `-Clean` wipes prior `.hemttout/` and `releases/` first.)

   `release.ps1` runs `hemtt check -p -Lc14 -e` then `hemtt release` in each subproject and the RAMET root, and repackages the produced zips into `releases\root_amet-{ver}-bundle.zip`. Unzip that into your Arma 3 root. Layout:
   - `@root_amet\` — addon + `$ARCHANGEL$`, `ramet\`, `tools\`, `batch\`, `docs\`
   - `@grad_meh\` — Intercept-based grad_meh mod
   - `@ocap_renderterrain\` — ocap-rt addon + Docker context (`ocap_renderterrain\`) + `ocap_renderterrain_process.bat`

2. Edit `@root_amet\batch\worlds.txt` (one CfgWorlds class per line). Stays in the mod folder — nothing is dropped into the Arma 3 root.

3. Run the pipeline
   ```cmd
   @root_amet\batch\99_full_pipeline.bat
   ```
   This chains the four steps below with pauses for the one manual action (Steam branch swap).

## Pipeline at a glance

All three mods (`@root_amet`, `@grad_meh`, `@ocap_renderterrain`) are loaded together in both Arma branches — the operator only swaps Steam betas between steps 1 and 2.

| Step | Script                          | Branch | What it does                                                                       |
| ---- | ------------------------------- | ------ | ---------------------------------------------------------------------------------- |
| 1    | `batch\01_export_grad_meh.bat`  | main   | `gradMehExportMap` per world → `Arma3\grad_meh\{world}\` (sat + GeoJSON + DEM + preview) |
| 2    | `batch\02_export_ocap.bat`      | diag   | `diag_exportTerrainSVG` + ocap exporter per world → `Arma3\ocap_exporter\{world}\`  |
| 3    | `batch\03_postprocess.bat`      | —      | ocap-rt Docker render → `ramet-postprocess` Docker (merge + PMTiles + SVG slice + WebP/pngquant + verify) → `Arma3\ramet_output\{world}\` |
| 4a   | `batch\04_deploy.bat`           | —      | Copy `Arma3\ramet_output\{world}\` into the local planner repo |
| 4b   | `batch\05_zip_for_upload.bat`   | —      | Pack each world (or `--bundle` all) into `Arma3\ramet_output\_zips\*.zip` for SFTP to a remote planner |

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

Host needs only **Docker Desktop**. Post-processing runs in two images:

- `ramet-postprocess` — built by `batch\03_postprocess.bat` from `tools\Dockerfile`. Bundles tippecanoe, pmtiles CLI, cwebp, pngquant, oxipng, Python 3.12 + `lxml` / `pyyaml` / `pillow`. The orchestrate entry-point runs inside it; nothing is installed on the host.
- `ocap-renderterrain` — upstream image built by `@ocap_renderterrain\ocap_renderterrain_process.bat`.

Build-time only (one-off, when producing a release):
- HEMTT on PATH (for `release.ps1`)
- Subproject toolchains: CMake/Conan/Intercept (grad_meh), Docker (ocap-rt)

Planner-side:
- `pmtiles.js` + `protomaps-leaflet.js` vendored under `JSOC-OPS-Warlords\server\warlords\static\lib\`

## Docs

- **`docs/BULK_EXPORT.md`** — full operator runbook (prereqs, troubleshooting, partial-output handling)
- **`docs/SCHEMA.md`** — `map.json` (`ramet-1`) reference
- **`docs/INTEGRATION.md`** — planner-side patches applied by this change set

## Constraints

- `reference_files/` and `.hemtt/project.toml` are not modified by tooling.
- No git commits made by scripts.
- New `map.json` schema is not backward-compatible with the planner's old format; old fields are dropped.
