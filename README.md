# RAMET

<p align="center">
  <img src="ramet_logo_clear.png" alt="RAMET logo" width="256">
</p>

<p align="center">
<!-- RAMET-RELEASE-BADGE:START -->
<img src="https://img.shields.io/badge/release-v1.5.0.1-blue" alt="release"> <img src="https://img.shields.io/badge/build-passing-brightgreen" alt="build">
<!-- RAMET-RELEASE-BADGE:END -->
</p>

**Root's Arma Map Export Tool** — all in one tool for exporting Arma 3 terrain into planner-ready raster + vector tile sets.

RAMET absorbs three export methods (`grad_meh` and an in-game GMS aerial exporter on the Arma main branch, `ocap-renderterrain` on the Arma diagnostic branch) plus a vendored, RAMET-patched Intercept, drives them through either batch queues or interactive spotlight UIs over [FlatDevil](github.com/A3-Root/FlatDevil), post-processes their outputs into a unified `ramet_output/{world}/` tree, and ships everything as a single `@root_amet` mod produced by one `hemtt release`. The output drops directly into the planner's tile source.

RAMET auto-detects which Arma binary is running (stable vs. diagnostic) and adapts: the Grad_meh and GMS spotlight tiles show on stable, the OCAP tile shows on diag, and the vendored Intercept host no-ops on the diag binary instead of crashing it.

## Quick start

**Requires [HEMTT](https://github.com/BrettMayson/HEMTT) on `PATH`** — both `release.ps1` and `release.sh` call `hemtt check` + `hemtt release` directly and will not build without it.

1. Build & install
   ```powershell
   .\release.ps1
   ```

   Windows release path. It now defaults to a clean rebuild of the packaged artifacts: `-Clean` and `-RebuildGradMehDll` are treated as on unless you pass `-NoClean` or `-NoRebuildGradMehDll`. Unless `-SkipSubprojects` is passed, it also builds `grad_meh_x64.dll` (Conan/CMake/Ninja), `MapExportExtension_x64.dll` (dotnet AOT publish), and `ocap_exporter_x64.dll` (go build) in turn. The script also checks the repo-side dependencies it needs for the full package surface, then runs `hemtt check -p -Lc14 -e` + `hemtt release` at the repo root.

   ```bash
   ./release.sh --skip-subprojects
   ```
   Linux/WSL packaging path. `grad_meh_x64.dll` and `MapExportExtension_x64.dll` always require a Windows toolchain (MSVC / .NET NativeAOT) and are never built here — bundled only if already present at `subprojects/grad_meh/build/lib64/grad_meh_x64.dll` and `subprojects/arma3MapExporter/publish/MapExportExtension_x64.dll`, otherwise HEMTT warns and packages without them. `ocap_exporter_x64.dll` is the exception: unless `--skip-subprojects` is passed, it's cross-compiled from Linux via `go` + `mingw-w64` (see Dependencies below).

   Unzip `releases\root_amet-{ver}.zip` into your Arma 3 root. `@root_amet\` is the only mod folder; it contains all 8 addons, `$FLATDEVIL$`, `ramet\`, `ocap_renderterrain\` (Docker context), `tools\`, `batch\`, `docs\`, and the native DLLs when they were built or already present in-tree. `grad_meh_x64.dll` is copied again under `intercept\` where Intercept scans for plugins.

   Prerequisite: `flatdevil_x64.dll` (from [FlatDevil](github.com/A3-Root/FlatDevil)) in the Arma 3 root, `@CBA_A3`, and a system Python 3.7+ install — FlatDevil discovers the interpreter at runtime.

2. Export a map from Arma using the spotlight UI for the process you want:
   - `RAMET — Grad_meh export` on the main branch
   - `RAMET — OCAP export (diag)` on the diagnostic branch
   - `RAMET — In-Game export (GMS)` on the main branch

   If you prefer the bulk queue path, optionally edit `@root_amet\batch\worlds.txt`. It may be empty. Put one `CfgWorlds` class per line and use `#` for comments.

3. Post-process the exported worlds:
   - Windows: `batch\03_postprocess.bat`
   - Linux / WSL / Git Bash: `batch/03_postprocess.sh`

   This is the step that merges exporter output, builds PMTiles, slices SVG layers, optimizes tiles, and runs verification — entirely via Docker, so it's genuinely cross-platform. It also runs the ocap-renderterrain Docker render if the helper script exists. `.sh` is a native bash reimplementation (not a wrapper around the `.bat`) — it runs the same Docker commands directly, so it works on a real Linux box, not just WSL.

4. Deploy or package:
   - Local planner copy: `batch\04_deploy.bat` or `batch/04_deploy.sh`
   - Upload zip: `batch\05_zip_for_upload.bat` or `batch/05_zip_for_upload.sh`

   Both wrappers pass through to `tools/deploy_to_planner.py` (stdlib-only, OS-agnostic). The deploy path needs `--planner-root` or `RAMET_PLANNER_ROOT`; the zip path writes under `ramet_output\_zips\`.

**Windows is the primary, fully end-to-end supported platform** — in-game export (steps that launch Arma itself) only works there. Linux support covers steps 3-5 above (Docker post-process, deploy, zip), which have no Windows-specific dependency. See "Linux support" under Dependencies for what that does and doesn't include.

## Supported Flows

`@root_amet` + `@CBA_A3` are loaded together in both Arma branches.

| Flow | Entry point | Branch | What it does |
| ---- | ----------- | ------ | ------------ |
| Spotlight Grad_meh | `RAMET — Grad_meh export` spotlight | main | Opens the Grad_meh picker UI for manual world selection |
| Spotlight OCAP | `RAMET — OCAP export (diag)` spotlight | diag | Opens the OCAP picker UI for manual world selection |
| Spotlight In-Game | `RAMET — In-Game export (GMS)` spotlight | main | Opens the GMS picker UI for manual world selection |
| Batch grad_meh | `batch\01_export_grad_meh.bat` (Windows only) | main | `gradMehExportMap` over `batch\worlds.txt` → `Arma3\grad_meh\{world}\` |
| Batch OCAP | `batch\02_export_ocap.bat` (Windows only) | diag | `diag_exportTerrainSVG` + ocap exporter over `batch\worlds.txt` → `Arma3\ocap_exporter\{world}\` |
| Post-process | `batch\03_postprocess.bat` / `batch/03_postprocess.sh` | n/a | Merge + PMTiles + SVG slice + optimize + verify → `Arma3\ramet_output\{world}\` |
| Deploy | `batch\04_deploy.bat` / `batch/04_deploy.sh` | n/a | Copy `Arma3\ramet_output\{world}\` into the planner `map_tiles\` directory |
| Zip | `batch\05_zip_for_upload.bat` / `batch/05_zip_for_upload.sh` | n/a | Pack `Arma3\ramet_output\{world}\` into upload zips |

01/02 launch `arma3_64.exe`/`arma3diag_x64.exe` directly and only make sense against a Windows Arma 3 install (Proton runs the same Windows binary, it doesn't change this) — there is no `.sh` equivalent for them. 03-05 are genuinely cross-platform: the `.bat` and `.sh` versions are independent native implementations of the same logic, not one wrapping the other.

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
├── modules/$FLATDEVIL$  # marker so FlatDevil adds `ramet` to sys.path
├── ramet/               # Python module exposed via FlatDevil (bulk / stage / ingame)
├── tools/                # Post-processing: orchestrate, slice_svg, geojson_to_pmtiles,
│                         #   merge_outputs, optimize_tiles, verify, deploy_to_planner
├── batch/                # Operator runbook (.bat/.sh) + worlds.txt
├── subprojects/          # NATIVE SOURCE ONLY: grad_meh (CMake/Conan/Rust), ocap-renderterrain
│                         #   (Go exporter + Docker context), arma3MapExporter (C# solution)
│                         #   — bundled whole into @root_amet via .hemtt/project.toml
│                         #   [files].include ("subprojects/**"), so the release zip is a
│                         #   genuine all-in-one: ready mod + everything needed to rebuild
│                         #   any native DLL from scratch
├── docs/                 # SCHEMA.md, BULK_EXPORT.md
├── output/               # Generated for reference/dev runs (`--from-reference`)
├── ramet_output/         # Generated in the Arma 3 root; pushed to the planner by step 4
└── reference_files/      # Read-only sample data (do not modify)
```

## Dependencies

### Windows release build (primary, fully supported)

Required to produce all three build-here native DLLs in the release zip:

- Windows 10/11
- HEMTT on `PATH`
- Docker Desktop
- Visual Studio 2022 with the Desktop development workload, MSVC v143, and the Windows SDK
- `VsDevCmd.bat` discoverable by `release.ps1` or provided via `RAMET_VSDEVCMD`
- `.NET 10 SDK`
- Conan 2.x, CMake 3.28+, Ninja, and a Rust toolchain (`cargo`) for `grad_meh`
- A Go toolchain (`go`) for `ocap_exporter`
- A system Python 3.10+ install if you also use the host-side deploy/zip helpers

### Linux support (secondary — steps 3-5 only, plus optional ocap_exporter cross-build)

`grad_meh_x64.dll` and `MapExportExtension_x64.dll` require a Windows toolchain
(MSVC / .NET NativeAOT) and cannot be built on Linux — not because of missing tooling, but
because arma3MapExporter's aerial capture is Windows GDI screen-capture and grad_meh's Conan
dependency graph (GDAL/PCL/OpenImageIO/Boost) has no MinGW binaries. Arma 3 on Linux runs through
Proton, which loads the same Windows `.dll` unmodified — there's no separate Linux artifact to
build for either of these regardless. `release.sh` always treats them as prebuilt; put them at
`subprojects/grad_meh/build/lib64/grad_meh_x64.dll` and
`subprojects/arma3MapExporter/publish/MapExportExtension_x64.dll` if you want them in the zip.

`ocap_exporter_x64.dll` (Go, `-buildmode=c-shared`) is the exception — it genuinely cross-compiles
from Linux via MinGW-w64, still producing a `.dll` for Intercept to load under Proton:

- Linux x86_64
- `bash`
- HEMTT on `PATH`
- Docker Engine (or equivalent) for the post-processing scripts
- `go` + `mingw-w64` (`x86_64-w64-mingw32-gcc`, `i686-w64-mingw32-gcc`) if you want
  `ocap_exporter_x64.dll` rebuilt; otherwise pass `--skip-subprojects` to package without it
- Python 3.10+ for the deploy helpers

`batch/03_postprocess.sh`, `04_deploy.sh`, and `05_zip_for_upload.sh` are native bash
reimplementations of the matching `.bat` files (not cmd.exe wrappers) — they run the same Docker
and Python calls directly, so they work on a real Linux box, not just WSL. `01`/`02` (in-game
export) have no Linux path: they launch the Arma client directly, and Proton doesn't change that.

### Runtime and export

- Arma 3 installed through Steam betas (native Windows, or Linux via Proton) for the actual game/export runtime
- `@root_amet` and `@CBA_A3` present in the Arma 3 root
- `flatdevil_x64.dll` from [FlatDevil](github.com/A3-Root/FlatDevil) in the Arma 3 root
- System Python 3.7+ for FlatDevil runtime discovery
- Docker running for `batch\03_postprocess.bat` / `batch/03_postprocess.sh`

### Post-processing image

- `ramet-postprocess` is built from `tools/Dockerfile` and bundles tippecanoe, pmtiles CLI, cwebp, pngquant, oxipng, Python 3.12, and the Python libraries required by `tools/orchestrate.py`
- `ocap-renderterrain` is the render image built by `@root_amet\ocap_renderterrain_process.bat` / `ocap_renderterrain_process.sh`

## Docs

- **`docs/BULK_EXPORT.md`** — full operator runbook (prereqs, troubleshooting, partial-output handling)
- **`docs/SCHEMA.md`** — `map.json` (`ramet-1`) reference
