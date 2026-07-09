# RAMET

**Root's Arma Map Export Tool** — single source of truth for exporting Arma 3 terrain into planner-ready raster + vector tile sets.

RAMET absorbs two upstream tools (`grad_meh` on Arma main branch, `ocap-renderterrain` on Arma diagnostic branch) plus a vendored, RAMET-patched Intercept, drives both with one bulk-export workflow over [FlatDevil](../FlatDevil), post-processes their outputs into a unified `output/{world}/` tree, and ships everything as a single `@root_amet` mod produced by one `hemtt release`. The output drops directly into [JSOC-OPS-Warlords](../JSOC-OPS-Warlords) as the planner's tile source.

RAMET auto-detects which Arma binary is running (stable vs. diagnostic) and adapts: the grad_meh/in-game spotlight tiles show on stable, the OCAP tile shows on diag, and the vendored Intercept host no-ops on the diag binary instead of crashing it.

## Quick start

1. Build & install
   ```powershell
   .\release.ps1
   ```
   (Skip the native DLL builds with `-SkipSubprojects` once they're already built. `-Clean` wipes prior `.hemttout/` and `releases/` first. `-RebuildGradMehDll` forces a rebuild of the grad_meh native plugin.)

   `release.ps1` builds the grad_meh native DLL (Conan/CMake/Ninja) and the arma3MapExporter native DLL (dotnet AOT publish), then runs a single `hemtt check -p -Lc14 -e` + `hemtt release` at the repo root. Unzip `releases\root_amet-{ver}.zip` into your Arma 3 root — `@root_amet\` is the only mod folder; it contains all 8 addons, `$FLATDEVIL$`, `ramet\`, `ocap_renderterrain\` (Docker context), `tools\`, `batch\`, `docs\`, and all four native DLLs (at the mod root, plus `grad_meh_x64.dll` again under `intercept\` where Intercept scans for plugins).

   Prerequisite: `flatdevil_x64.dll` (from [FlatDevil](../FlatDevil)) in the Arma 3 root, `@CBA_A3`, and a system Python 3.7+ install — FlatDevil discovers the interpreter at runtime.

2. Edit `@root_amet\batch\worlds.txt` (one CfgWorlds class per line). Stays in the mod folder — nothing is dropped into the Arma 3 root.

3. Run the pipeline
   ```cmd
   @root_amet\batch\99_full_pipeline.bat
   ```
   This chains the four steps below with pauses for the one manual action (Steam branch swap).

## Pipeline at a glance

`@root_amet` + `@CBA_A3` are loaded together in both Arma branches — the operator only swaps Steam betas between steps 1 and 2.

| Step | Script                          | Branch | What it does                                                                       |
| ---- | ------------------------------- | ------ | ---------------------------------------------------------------------------------- |
| 1    | `batch\01_export_grad_meh.bat`  | main   | `gradMehExportMap` per world → `Arma3\grad_meh\{world}\` (sat + GeoJSON + DEM + preview) |
| 2    | `batch\02_export_ocap.bat`      | diag   | `diag_exportTerrainSVG` + ocap exporter per world → `Arma3\ocap_exporter\{world}\`  |
| 3    | `batch\03_postprocess.bat`      | —      | ocap-rt Docker render → `ramet-postprocess` Docker (merge + PMTiles + SVG slice + WebP/pngquant + verify) → `Arma3\ramet_output\{world}\` |
| 4a   | `batch\04_deploy.bat`           | —      | Copy `Arma3\ramet_output\{world}\` into the local planner repo |
| 4b   | `batch\05_zip_for_upload.bat`   | —      | Pack each world (or `--bundle` all) into `Arma3\ramet_output\_zips\*.zip` for SFTP to a remote planner |

Inside Arma, both bulk-export missions use FlatDevil (`["ramet.bulk.next_world", ["grad_meh"]] call ramet_fnc_fdCall` etc.) to share queue state with the Python `ramet/` module, so the run survives crashes and per-world branch swaps.

Step 3 can be paused between worlds by creating `Arma3\ramet.pause` while `batch\03_postprocess.bat` is running. The Docker orchestrator checks for that sentinel before starting each next world and waits while it exists. Delete `Arma3\ramet.pause` to resume.

## Layout

```
RAMET/
├── .hemtt/hooks/        # post_build bundles $FLATDEVIL$, ramet/, ocap_renderterrain/, DLLs into @root_amet
├── addons/              # ALL addons, prefixed z\root_amet\addons\<name>:
│                        #   main, grad_meh_main, grad_meh_ui, ocap_exporter, ocap_ui,
│                        #   a3me_main, a3me_exporter, intercept_core (vendored, RAMET-patched)
├── include/             # x\cba\... include tree (a3me script_macros dependency)
├── vendor/intercept/    # intercept_x64.dll
├── modules/$FLATDEVIL$  # marker so FlatDevil adds `ramet` + `ocap_renderterrain` to sys.path
├── modules/ocap_renderterrain/  # Python pkg (merged with Docker context at build time)
├── ramet/               # Python module exposed via FlatDevil (bulk / stage / kickoff)
├── tools/                # Post-processing: orchestrate, slice_svg, geojson_to_pmtiles,
│                         #   merge_outputs, optimize_tiles, verify, deploy_to_planner
├── batch/                # Operator runbook (.bat) + worlds.txt
├── subprojects/          # NATIVE SOURCE ONLY: grad_meh (CMake/Conan/Rust), ocap-renderterrain
│                         #   (Go exporter + Docker context), arma3MapExporter (C# solution)
├── docs/                 # SCHEMA.md, BULK_EXPORT.md, INTEGRATION.md
├── output/               # Generated; pushed to planner repo by step 4
└── reference_files/      # Read-only sample data (do not modify)
```

## Dependencies

Host needs only **Docker Desktop**. Post-processing runs in two images:

- `ramet-postprocess` — built by `batch\03_postprocess.bat` from `tools\Dockerfile`. Bundles tippecanoe, pmtiles CLI, cwebp, pngquant, oxipng, Python 3.12 + `lxml` / `pyyaml` / `pillow`. The orchestrate entry-point runs inside it; nothing is installed on the host.
- `ocap-renderterrain` — upstream image built by `@root_amet\ocap_renderterrain_process.bat`.

Build-time only (one-off, when producing a release):
- HEMTT on PATH (for `release.ps1`)
- Native toolchains: CMake/Conan/Rust/Intercept SDK (grad_meh DLL), .NET 10 SDK + VS 2022 (arma3MapExporter DLL, AOT)

Signing: `hemtt release` auto-generates a `root_amet_{version}` key and signs all 8 PBOs, shipping `keys\` alongside them — no manual step. This only matters for servers running `verifySignatures`.

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
