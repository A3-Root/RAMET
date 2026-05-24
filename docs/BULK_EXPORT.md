# RAMET bulk-export runbook

## Prereqs

- Arma 3 main + diagnostic branches both installed (Steam → Properties → Betas).
- Mods present in Arma3 root: `@root_amet`, `@grad_meh`, `@intercept`, `@CBA_A3`, `@ocap_renderterrain`.
  After `hemtt release` from RAMET root, unzip `releases/{ver}/root_amet-{ver}.zip` directly into the Arma 3 root — the bundle contains all four `@` folders, `batch/`, `tools/`, and the Docker context.
- Docker Desktop running (for post-processing).
- Python 3.11+ on PATH with `lxml`, `pyyaml`, `pillow`.
- `tippecanoe`, `pmtiles` CLI on PATH (or run via Docker; orchestrate.py emits a warning and skips if missing).
- `cwebp`, `pngquant`, `oxipng` on PATH (raster optimization is skipped layer-by-layer if missing).

## 1. Prep

Edit `batch/worlds.txt` — one CfgWorlds class name per line. Comments with `#`. The same file is consumed by both Arma passes.

Copy `batch/worlds.txt` to your Arma 3 root (or the batch scripts will do it for you on first run).

## 2. grad_meh export (main branch)

```
batch\01_export_grad_meh.bat
```

Switches into Arma 3 root, verifies `arma3_64.exe`, deletes any stale `ramet_state/bulk_state.json`, launches Arma. Inside the game, `ramet_fnc_bulkExportGradMeh` runs immediately and loops through the world list, calling `gradMehExportMap [w, true, true, true, true, true, true, true]` once per world and polling `gradMehExportRunning` until done. After each world, `ramet.stage.move_grad_meh()` shifts `Arma3/grad_meh/{w}/` into `Arma3/ramet_intermediate/grad_meh/{w}/`.

You must launch Arma with one of the listed worlds. The loop iterates the rest by reloading the appropriate world; if a queued world differs from the loaded one, the loop logs a warning and skips it — you'll see that in `ramet_state/ramet_bulk.log`.

When the queue is exhausted, the mission ends with `endMission "END1"`. Close Arma.

## 3. Branch swap

Steam → Arma 3 → Properties → Betas → choose **`development`** (diagnostic) and let Steam re-validate. The diag binary is `arma3diag_x64.exe`.

## 4. ocap-renderterrain export (diag branch)

```
batch\02_export_ocap.bat
```

Same loop pattern, this time wrapping `\z\ocap_exporter\addons\exporter\export_data.sqf` from the `@ocap_renderterrain` mod. Requires `diag_exportTerrainSVG` (diag-only).

After each world, `ramet.stage.move_ocap()` shifts `Arma3/ocap_exporter/{w}/` into `ramet_intermediate/ocap_rt/{w}/`. If you toggle the "kickoff Docker render" option in-game (`ramet.kickoff.run_docker(world)`), the Docker render of that world starts in a background process while Arma continues to the next world.

## 5. Post-process (no Arma)

```
batch\03_postprocess.bat
```

1. Runs `ocap_renderterrain_process.bat` if not already kicked off — builds the Docker image and renders any remaining worlds.
2. Runs `python tools/orchestrate.py --all`. Per world: merge raster pyramids, build PMTiles from grad_meh GeoJSONs, slice the ocap-rt SVG into per-class layers, optimize tiles (WebP/pngquant/oxipng), write `map.json` + `source.json`, verify.
3. Bails on any verify error so the operator sees the failure before deploying.

Re-runnable: orchestrate is idempotent per world; rerun with `--world altis` to redo just one.

## 6. Deploy

```
batch\04_deploy.bat
```

Copies `output/{world}/` into `JSOC-OPS-Warlords/server/warlords/map_tiles/{world}/`. Add `--prune-legacy` to wipe planner-side maps that lack a RAMET `map.json` (be careful — verify the diff first with `--dry-run`).

## Partial-output handling

- If a map fails the grad_meh pass (encrypted ebo / unsupported), step 1 logs the failure to `ramet_state/ramet_bulk.log`; step 5 emits a manifest with `"source": "ocap"` and no `vectorSource`. Planner hides the vector overlay toggles for that map.
- Same in reverse if a map only has grad_meh output.
- Manifest declares only what was produced; the planner renders only what's declared. No client-side fallback logic.

## Troubleshooting

- "world mismatch" in `ramet_bulk.log` → the loop tried to process world X but Arma loaded world Y. Re-launch Arma with that world (or accept the skip; remaining worlds still process).
- `diag_exportTerrainSVG` missing → you're on main branch, not diag. Steam beta selection.
- Docker build OOM → set `OCAP_RENDER_DOCKER_MEMORY=24g` (default 48g) before running step 3.
- PMTiles build fails with "tippecanoe not found" → install via WSL / scoop / Docker. orchestrate.py logs the skip and continues without `vectorSource`.
