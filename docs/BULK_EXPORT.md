# RAMET bulk-export runbook

RAMET has two supported export paths:

- Automatic batch export, driven by `batch\worlds.txt`
- Interactive export, driven by the main-menu spotlight tiles

The automatic path is best for repeatable queues. The interactive path is best
when the operator wants to pick maps manually in the in-game UI.

**Windows is the primary, fully supported platform end to end** — exporting
from Arma (steps 1-2 below) only works there, Proton included (it still runs
the Windows client). Steps 3-5 (post-process/deploy/zip) have no Windows-only
dependency and are genuinely supported on Linux too.

## Recommended workflow

This is the default path:

1. Export maps from the spotlight UI for the process you want.
2. Run `batch\03_postprocess.bat` (Windows) or `batch/03_postprocess.sh` (Linux/WSL/Git Bash).
3. Run `batch\04_deploy.bat` / `batch/04_deploy.sh` or
   `batch\05_zip_for_upload.bat` / `batch/05_zip_for_upload.sh` as needed.

The `.sh` scripts are native bash reimplementations of the matching `.bat`
files — they run the same Docker/Python calls directly, not a wrapper around
the `.bat` through `cmd.exe`. They work on a real Linux box, WSL, or Git Bash
equally. `01`/`02` (in-game export) have no `.sh` equivalent — they launch the
Arma client directly and only make sense against a live client session.

## Prereqs

- Arma 3 main and/or diagnostic branches installed through Steam betas (native
  Windows, or Linux via Proton for the post-process-only flow).
- `@root_amet` and `@CBA_A3` present in the Arma 3 root.
- `flatdevil_x64.dll` present in the Arma 3 root for the batch UI.
- Docker Desktop (Windows) or Docker Engine (Linux) running.
- Host Python 3.10+ on `PATH` for deployment and zip packaging.

After `release.ps1` or `release.sh`, unzip `releases\root_amet-{ver}.zip`
into the Arma 3 root. `@root_amet` contains the addons, `batch\`, `tools\`,
`docs\`, and the bundled native DLLs when they were built or already present in
the tree.

## 1. Choose a queue source

### Automatic batch queue

Edit `@root_amet\batch\worlds.txt` if you want to pre-seed a batch queue. The
file may be empty. Put one `CfgWorlds` class name per line and use `#` for
comments.

The batch scripts read this file directly from the mod folder.

### Interactive spotlight

If you do not want to pre-seed the queue, launch Arma and use the main-menu
spotlight tiles:

- `RAMET — Grad_meh export`
- `RAMET — OCAP export (diag)`
- `RAMET — In-Game export (GMS)`

Those tiles open the respective picker UIs. Grad_meh and GMS are main-branch
paths. OCAP requires the diagnostic branch.

## 2. Optional batch export

### 2a. grad_meh

Run this on the Arma 3 main branch (Windows only — no shell equivalent, this
launches the Arma client directly):

```bat
batch\01_export_grad_meh.bat
```

This starts the Grad_meh bulk loop and exports each queued world into
`Arma3\grad_meh\{world}\`.

Notes:

- The script resets `ramet_state\bulk_state.json` before launch so the queue
  starts clean.
- Any world mismatch is logged and skipped, not retried forever.
- The pass finishes when `ramet_state\ramet_bulk.log` reports completion.

### 2b. ocap-renderterrain

Switch Arma 3 to the diagnostic/development branch and run (Windows only —
no shell equivalent, this launches the Arma diagnostic client directly):

```bat
batch\02_export_ocap.bat
```

This exports raw SVG / ASC data into `Arma3\ocap_exporter\{world}\`.

Notes:

- SVG export requires the diagnostic executable.
- This pass is resumable because it keeps its own bulk state.

## 3. Post-process

Run the Docker-based merge and verification step:

```bat
batch\03_postprocess.bat
```

Shell equivalent:

```bash
batch/03_postprocess.sh
```

What it does:

1. Optionally runs `ocap_renderterrain_process.bat` (or `.sh` on Linux/WSL/Git
   Bash) to render `ocap_renderterrain_output\{world}\`.
2. Builds the `ramet-postprocess` image from `tools\Dockerfile`.
3. Runs `tools/orchestrate.py` inside Docker to merge outputs, build PMTiles,
   slice SVG layers, render ingame pyramids, optimize tiles, and verify.
4. Writes the final world tree to `Arma3\ramet_output\{world}\`.

Useful flag:

- `--skip-ocap` skips the upstream ocap render if those outputs already exist.

If `batch\render_worlds.txt` exists, it limits the Docker render / merge to the
listed worlds.

## 4. Deploy

Local planner on the same machine:

```bat
batch\04_deploy.bat
```

Shell equivalent:

```bash
batch/04_deploy.sh
```

Remote planner upload:

```bat
batch\05_zip_for_upload.bat
batch\05_zip_for_upload.bat --bundle
```

Shell equivalents:

```bash
batch/05_zip_for_upload.sh
batch/05_zip_for_upload.sh --bundle
```

`04_deploy.bat` copies the world trees into
the chosen planner `map_tiles\{world}\` directory. `05_zip_for_upload.bat`
writes per-world zips under `Arma3\ramet_output\_zips\`.

## Interactive spotlight flow

The spotlight tiles open the upstream UIs and let the operator choose maps in
the dialog itself.

- Grad_meh spotlight: main branch
- OCAP spotlight: diagnostic branch
- In-Game spotlight: main branch

The ingame picker populates its grid from `CfgWorldList`, remembers selection
state while the dialog is open, and launches the export when the dialog closes
with a selection. The OCAP and Grad_meh pickers follow the same manual-select
pattern.

## Partial output

- A world can be published with only Grad_meh output, only OCAP output, only
  in-game output, or any combination.
- The manifest only advertises layers that actually exist on disk.
- Missing `vectorSource` or `svgLayers` is valid and intentional when those
  stages were not produced.
- `source.json` keeps provenance for the source directories, which the verifier
  uses to sanity-check the sat source.

## Troubleshooting

- `diag_exportTerrainSVG` missing means you are not on the diagnostic branch.
- `03_postprocess.bat --skip-ocap` is useful when only the later merge /
  optimize / deploy stages need to be rerun.
- If `ramet-postprocess` complains about missing tools, rebuild the image from
  the repo root.
- If deployment skips a world, confirm that `ramet_output\{world}\map.json`
  exists.
- `01_export_grad_meh` / `02_export_ocap` have no Linux path — they launch the
  Arma client directly. Run those on Windows and only use the Linux `.sh`
  scripts for steps 3-5.
