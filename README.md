# RAMET

**Root's Arma Map Export Tool** — single source of truth for exporting Arma 3 terrain into planner-ready raster + vector tile sets.

RAMET absorbs two upstream tools (`grad_meh` on Arma main branch, `ocap-renderterrain` on Arma diagnostic branch) plus a vendored, RAMET-patched Intercept, drives them through either batch queues or interactive spotlight UIs over [FlatDevil](github.com/A3-Root/FlatDevil), post-processes their outputs into a unified `ramet_output/{world}/` tree, and ships everything as a single `@root_amet` mod produced by one `hemtt release`. The output drops directly into the planner's tile source.

RAMET auto-detects which Arma binary is running (stable vs. diagnostic) and adapts: the Grad_meh and GMS spotlight tiles show on stable, the OCAP tile shows on diag, and the vendored Intercept host no-ops on the diag binary instead of crashing it.

## Quick start

1. Build & install
   ```powershell
   .\release.ps1
   ```

   Windows release path. It now defaults to a clean rebuild of the packaged artifacts: `-Clean` and `-RebuildGradMehDll` are treated as on unless you pass `-NoClean` or `-NoRebuildGradMehDll`. The script also checks the repo-side dependencies it needs for the full package surface, then runs `hemtt check -p -Lc14 -e` + `hemtt release` at the repo root.

   ```bash
   ./release.sh --skip-subprojects
   ```
   Linux/WSL packaging path. It also defaults to clean + grad_meh rebuild checks, with `--no-clean` and `--no-rebuild-grad-meh-dll` as opt-outs. It does not build the Windows-native DLLs in-repo. If `subprojects/grad_meh/build/lib64/grad_meh_x64.dll` and `subprojects/arma3MapExporter/publish/MapExportExtension_x64.dll` already exist, they are bundled; otherwise HEMTT warns and packages without them.

   Unzip `releases\root_amet-{ver}.zip` into your Arma 3 root. `@root_amet\` is the only mod folder; it contains all 8 addons, `$FLATDEVIL$`, `ramet\`, `ocap_renderterrain\` (Docker context), `tools\`, `batch\`, `docs\`, and the native DLLs when they were built or already present in-tree. `grad_meh_x64.dll` is copied again under `intercept\` where Intercept scans for plugins.

   Prerequisite: `flatdevil_x64.dll` (from [FlatDevil](github.com/A3-Root/FlatDevil)) in the Arma 3 root, `@CBA_A3`, and a system Python 3.7+ install — FlatDevil discovers the interpreter at runtime.

2. Export a map from Arma using the spotlight UI for the process you want:
   - `RAMET — Grad_meh export` on the main branch
   - `RAMET — OCAP export (diag)` on the diagnostic branch
   - `RAMET — In-Game export (GMS)` on the main branch

   If you prefer the bulk queue path, optionally edit `@root_amet\batch\worlds.txt`. It may be empty. Put one `CfgWorlds` class per line and use `#` for comments.

3. Post-process the exported worlds:
   - Windows: `batch\03_postprocess.bat`
   - WSL/Git Bash on Windows: `batch/03_postprocess.sh`

   This is the step that merges exporter output, builds PMTiles, slices SVG layers, optimizes tiles, and runs verification. On Windows it can also run the ocap-renderterrain Docker render if the helper batch exists. The shell wrapper delegates to the batch file through `cmd.exe`.

4. Deploy or package:
   - Local planner copy: `batch\04_deploy.bat` or `batch/04_deploy.sh`
   - Upload zip: `batch\05_zip_for_upload.bat` or `batch/05_zip_for_upload.sh`

   Both wrappers pass through to `tools/deploy_to_planner.py`. The deploy path needs `--planner-root` or `RAMET_PLANNER_ROOT`; the zip path writes under `ramet_output\_zips\`.

## Supported Flows

`@root_amet` + `@CBA_A3` are loaded together in both Arma branches.

| Flow | Entry point | Branch | What it does |
| ---- | ----------- | ------ | ------------ |
| Spotlight Grad_meh | `RAMET — Grad_meh export` spotlight | main | Opens the Grad_meh picker UI for manual world selection |
| Spotlight OCAP | `RAMET — OCAP export (diag)` spotlight | diag | Opens the OCAP picker UI for manual world selection |
| Spotlight In-Game | `RAMET — In-Game export (GMS)` spotlight | main | Opens the GMS picker UI for manual world selection |
| Batch grad_meh | `batch\01_export_grad_meh.bat` / `batch/01_export_grad_meh.sh` | main | `gradMehExportMap` over `batch\worlds.txt` → `Arma3\grad_meh\{world}\` |
| Batch OCAP | `batch\02_export_ocap.bat` / `batch/02_export_ocap.sh` | diag | `diag_exportTerrainSVG` + ocap exporter over `batch\worlds.txt` → `Arma3\ocap_exporter\{world}\` |
| Post-process | `batch\03_postprocess.bat` / `batch/03_postprocess.sh` | n/a | Merge + PMTiles + SVG slice + optimize + verify → `Arma3\ramet_output\{world}\` |
| Deploy | `batch\04_deploy.bat` / `batch/04_deploy.sh` | n/a | Copy `Arma3\ramet_output\{world}\` into the planner `map_tiles\` directory |
| Zip | `batch\05_zip_for_upload.bat` / `batch/05_zip_for_upload.sh` | n/a | Pack `Arma3\ramet_output\{world}\` into upload zips |

Inside Arma, the automatic batch exporters use FlatDevil (`["ramet.bulk.next_world", ["grad_meh"]] call ramet_fnc_fdCall` etc.) to share queue state with the Python `ramet/` module, so the run survives crashes and per-world relaunches.

Step 3 can be paused between worlds by creating `Arma3\ramet.pause` while `batch\03_postprocess.bat` is running. The Docker orchestrator checks for that sentinel before starting the next world and waits while it exists. Delete `Arma3\ramet.pause` to resume.

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
├── batch/                # Operator runbook (.bat/.sh) + worlds.txt
├── subprojects/          # NATIVE SOURCE ONLY: grad_meh (CMake/Conan/Rust), ocap-renderterrain
│                         #   (Go exporter + Docker context), arma3MapExporter (C# solution)
├── docs/                 # SCHEMA.md, BULK_EXPORT.md, INTEGRATION.md
├── output/               # Generated for reference/dev runs (`--from-reference`)
├── ramet_output/         # Generated in the Arma 3 root; pushed to the planner by step 4
└── reference_files/      # Read-only sample data (do not modify)
```

## Dependencies

### Windows release build

Required to produce the native DLLs in the release zip:

- Windows 10/11
- HEMTT on `PATH`
- Docker Desktop
- Visual Studio 2022 with the Desktop development workload, MSVC v143, and the Windows SDK
- `VsDevCmd.bat` discoverable by `release.ps1` or provided via `RAMET_VSDEVCMD`
- `.NET 10 SDK`
- Conan 2.x, CMake 3.28+, Ninja, and a Rust toolchain (`cargo`) for `grad_meh`
- A system Python 3.10+ install if you also use the host-side deploy/zip helpers

### Linux release packaging

Supported for packaging existing artifacts and for Docker-based post-processing:

- Linux x86_64
- `bash`
- HEMTT on `PATH`
- Docker Engine or an equivalent runtime for the post-processing scripts
- Python 3.10+ for the deploy helpers and any direct host-side tooling

The Linux `release.sh` wrapper does not build the Windows-native DLLs in-repo. If you want those DLLs inside the release zip, build them on Windows first and then rerun the Linux packaging step, or keep the prebuilt artifacts in `subprojects/grad_meh/build/lib64/` and `subprojects/arma3MapExporter/publish/`.

The `batch/*.sh` wrappers are thin shell launchers that delegate to the matching `.bat` scripts through `cmd.exe`. They are useful from WSL or Git Bash on Windows, but the actual Arma launch steps still depend on the Windows game install.

### Runtime and export

- Arma 3 installed through Steam betas on Windows for the actual game/export runtime
- `@root_amet` and `@CBA_A3` present in the Arma 3 root
- `flatdevil_x64.dll` from [FlatDevil](github.com/A3-Root/FlatDevil) in the Arma 3 root
- System Python 3.7+ for FlatDevil runtime discovery
- Docker running for `batch\03_postprocess.bat`

### Post-processing image

- `ramet-postprocess` is built from `tools/Dockerfile` and bundles tippecanoe, pmtiles CLI, cwebp, pngquant, oxipng, Python 3.12, and the Python libraries required by `tools/orchestrate.py`
- `ocap-renderterrain` is the upstream image built by `@root_amet\ocap_renderterrain_process.bat`

## Docs

- **`docs/BULK_EXPORT.md`** — full operator runbook (prereqs, troubleshooting, partial-output handling)
- **`docs/SCHEMA.md`** — `map.json` (`ramet-1`) reference
