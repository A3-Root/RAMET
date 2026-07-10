# RAMET

<p align="center">
  <img src="ramet_logo_clear.png" alt="RAMET logo" width="256">
</p>

<p align="center">
<!-- RAMET-RELEASE-BADGE:START -->
<img src="https://img.shields.io/badge/release-v1.5.0.1-blue" alt="release"> <img src="https://img.shields.io/badge/build-passing-brightgreen" alt="build">
<!-- RAMET-RELEASE-BADGE:END -->
</p>

**Root's Arma Map Export Tool** — all-in-one export of Arma 3 terrain into planner-ready raster + vector tile sets.

RAMET combines three export methods — `grad_meh` (satellite + vector), `ocap-renderterrain` (tile pyramids, diag branch), and an in-game GMS aerial exporter — plus a vendored, RAMET-patched Intercept, into a single `@root_amet` mod. Exports run from in-game spotlight UIs or an unattended batch queue, post-process into a unified `ramet_output/{world}/` tile tree via Docker, and deploy straight into a web map planner.

RAMET auto-detects the running Arma binary (stable vs. diagnostic) and adapts: Grad_meh/GMS spotlight tiles show on stable, the OCAP tile shows on diag, and the vendored Intercept host no-ops on diag instead of crashing.

**Windows is the primary, fully supported platform end to end.** Linux covers post-process/deploy/zip (steps 3-5) plus an optional `ocap_exporter` cross-build — see [Dependencies](#dependencies).

## Quick start

Requires [HEMTT](https://github.com/BrettMayson/HEMTT) on `PATH`. 

1. **Run** `.\release.ps1` (Windows) or `./release.sh --skip-subprojects` (Linux/WSL). This automatically checks and prompts the user to install necessary dependencies.
2. **Unzip** `releases\root_amet-{ver}.zip` into your Arma 3 root.
   Also needs `flatdevil_x64.dll` ([FlatDevil](github.com/A3-Root/FlatDevil)), `@CBA_A3`, any terrains, and system Python 3.7+ in the Arma 3 root.
2. **Export** a map from the spotlight UI (`RAMET — Grad_meh export`, `RAMET — OCAP export (diag)`, `RAMET — In-Game export (GMS)`), or pre-seed `@root_amet\batch\worlds.txt` for the unattended batch queue.
3. **Post-process**: `batch\03_postprocess.bat` (Windows) / `batch/03_postprocess.sh` (Linux/WSL/Git Bash) — merges exports, builds PMTiles, slices SVG, optimizes tiles, verifies. Entirely Docker-based.
4. **Deploy or package**: `batch\04_deploy.bat`/`.sh` (local planner copy, needs `--planner-root` or `RAMET_PLANNER_ROOT`) or `batch\05_zip_for_upload.bat`/`.sh` (upload zips under `ramet_output\_zips\`).

Step 3 can be paused between worlds by creating `Arma3\ramet.pause` — delete it to resume.

### Build script details

| Script | Platform | Native DLL builds |
| --- | --- | --- |
| `release.ps1` | Windows | Builds all three: `grad_meh_x64.dll` (Conan/CMake/Ninja), `MapExportExtension_x64.dll` (dotnet AOT), `ocap_exporter_x64.dll` (go), unless `-SkipSubprojects`. Defaults to `-Clean` + `-RebuildGradMehDll`; opt out with `-NoClean` / `-NoRebuildGradMehDll`. |
| `release.sh` | Linux/WSL | `grad_meh_x64.dll` / `MapExportExtension_x64.dll` always require a Windows toolchain — bundled only if already present under `subprojects/`, never built here. `ocap_exporter_x64.dll` cross-compiles via `go` + `mingw-w64` unless `--skip-subprojects`. |

Both run `hemtt check -p -Lc14 -e` + `hemtt release` at the repo root; `grad_meh_x64.dll` is copied both to `@root_amet\` root and `@root_amet\intercept\` (where Intercept scans for plugins).

## Supported flows

`@root_amet` + `@CBA_A3` load together on both Arma branches.

| Flow | Entry point | Branch | Output |
| --- | --- | --- | --- |
| Spotlight Grad_meh | `RAMET — Grad_meh export` | main | Manual world picker |
| Spotlight OCAP | `RAMET — OCAP export (diag)` | diag | Manual world picker |
| Spotlight In-Game | `RAMET — In-Game export (GMS)` | main | Manual world picker |
| Batch grad_meh | `batch\01_export_grad_meh.bat` (Windows only) | main | `Arma3\grad_meh\{world}\` |
| Batch OCAP | `batch\02_export_ocap.bat` (Windows only) | diag | `Arma3\ocap_exporter\{world}\` |
| Post-process | `batch\03_postprocess.bat` / `.sh` | any | `Arma3\ramet_output\{world}\` |
| Deploy | `batch\04_deploy.bat` / `.sh` | any | Planner `map_tiles\` directory |
| Zip | `batch\05_zip_for_upload.bat` / `.sh` | any | `ramet_output\_zips\` |

`01`/`02` launch `arma3_64.exe`/`arma3diag_x64.exe` directly (Proton doesn't change this) — no `.sh` equivalent. `03`-`05` are genuine independent native implementations on both platforms, not one wrapping the other.

Batch exporters advance their queue via FlatDevil (`["ramet.bulk.next_world", ["grad_meh"]] call ramet_fnc_fdCall`), so runs survive crashes and per-world relaunches.

## Layout

```
RAMET/
├── addons/          # All addons (prefix z\root_amet\addons\<name>): main, grad_meh_main/ui,
│                    # ocap_exporter/ui, a3me_main/exporter, intercept_core
├── include/         # x\cba\... include tree (a3me script_macros dependency)
├── vendor/intercept/ # intercept_x64.dll
├── modules/$FLATDEVIL$ # FlatDevil marker (adds ramet/ to sys.path)
├── ramet/           # Python module exposed via FlatDevil (bulk / stage / ingame)
├── tools/           # Post-processing: orchestrate, merge_outputs, geojson_to_pmtiles,
│                    # optimize_tiles, verify, deploy_to_planner
├── batch/           # Operator runbook (.bat/.sh) + worlds.txt
├── subprojects/     # Native source: grad_meh, ocap-renderterrain, arma3MapExporter —
│                    # bundled whole into @root_amet (see .hemtt/project.toml), so the
│                    # release zip is a genuine all-in-one: ready mod + rebuildable source
├── docs/            # SCHEMA.md, BULK_EXPORT.md
├── output/          # Generated for reference/dev runs (--from-reference)
├── ramet_output/    # Generated in the Arma 3 root; pushed to the planner by step 4
└── reference_files/ # Read-only sample data — never modified
```

`.hemtt/hooks/post_build` stages the FlatDevil marker, `ramet/`, the ocap-renderterrain Docker context, `docs/`/`tools/`/`batch/`, and the native DLLs into `@root_amet`.

## Dependencies

### Windows (primary)

- Windows 10/11, HEMTT on `PATH`, Docker Desktop
- Visual Studio 2022 (Desktop C++ workload, MSVC v143, Windows SDK) + `VsDevCmd.bat` (auto-discovered, or set `RAMET_VSDEVCMD`)
- .NET 10 SDK; Conan 2.x, CMake 3.28+, Ninja, Rust (`cargo`) for `grad_meh`; Go for `ocap_exporter`
- Python 3.10+ for the host-side deploy/zip helpers

### Linux (secondary — steps 3-5, plus optional ocap_exporter cross-build)

`grad_meh_x64.dll` and `MapExportExtension_x64.dll` can't be built on Linux — `arma3MapExporter`'s aerial capture is Windows GDI screen-capture, and `grad_meh`'s Conan dependency graph (GDAL/PCL/OpenImageIO/Boost) has no MinGW binaries. Since Arma 3 on Linux runs through Proton (the same Windows `.dll`, unmodified), there's no separate Linux artifact to build for either regardless — `release.sh` always treats them as prebuilt.

`ocap_exporter_x64.dll` is the exception: it genuinely cross-compiles from Linux via MinGW-w64.

- Linux x86_64, `bash`, HEMTT on `PATH`, Docker Engine
- `go` + `mingw-w64` (`x86_64-w64-mingw32-gcc`, `i686-w64-mingw32-gcc`) to rebuild `ocap_exporter_x64.dll` — or pass `--skip-subprojects` to package without it
- Python 3.10+ for the deploy helpers

`batch/03_postprocess.sh`, `04_deploy.sh`, `05_zip_for_upload.sh` are native bash reimplementations (not cmd.exe wrappers) — real Linux, WSL, and Git Bash all work equally. `01`/`02` have no Linux path.

### Runtime and export

- Arma 3 (native Windows, or Linux via Proton) with `@root_amet` + `@CBA_A3` in the Arma 3 root
- `flatdevil_x64.dll` ([FlatDevil](github.com/A3-Root/FlatDevil)) in the Arma 3 root, system Python 3.7+ for its runtime discovery
- Docker running for the post-process step

### Post-processing image

- `ramet-postprocess` (`tools/Dockerfile`): tippecanoe, pmtiles CLI, cwebp, pngquant, oxipng, Python 3.12 + `tools/orchestrate.py` deps
- `ocap-renderterrain`: built by `ocap_renderterrain_process.bat` / `.sh`

## Docs

- **[`docs/BULK_EXPORT.md`](docs/BULK_EXPORT.md)** — full operator runbook (prereqs, troubleshooting, partial-output handling)
- **[`docs/SCHEMA.md`](docs/SCHEMA.md)** — `map.json` (`ramet-1`) reference

## License

[APL-SA](LICENSE) (Arma Public License Share Alike) — see [`LICENSE`](LICENSE) for full terms and third-party notices.
