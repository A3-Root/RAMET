# RAMET bulk-export runbook

## Prereqs

- Arma 3 main + diagnostic branches both installed (Steam → Properties → Betas).
- Mods present in Arma3 root: `@root_amet`, `@grad_meh`, `@intercept`, `@CBA_A3`, `@ocap_renderterrain`.
  After `hemtt release` from RAMET root, unzip `releases/{ver}/root_amet-{ver}.zip` directly into the Arma 3 root — the bundle contains all four `@` folders, `batch/`, `tools/`, and the Docker context.
- Docker Desktop running — **only host dependency for post-processing**. All tippecanoe / pmtiles / cwebp / pngquant / oxipng / Python / lxml work runs inside the `ramet-postprocess` image (built once from `tools\Dockerfile`).

## 1. Prep

Edit `@root_amet\batch\worlds.txt` — one CfgWorlds class name per line. Comments with `#`. The same file is consumed by both Arma passes, read directly from the mod folder (nothing is dropped into the Arma 3 root).

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

## 5. Post-process (no Arma — all Docker)

```
batch\03_postprocess.bat
```

1. Runs `ocap_renderterrain_process.bat` (upstream image) over `<Arma3>\ocap_exporter\` → writes `<Arma3>\ocap_renderterrain_output\{world}\`.
2. Builds the `ramet-postprocess` image from `tools\Dockerfile` (cached after first build).
3. Runs `docker run --rm -v <Arma3>:/work ramet-postprocess:latest --all`. Per world: merge raster pyramids, build PMTiles from grad_meh GeoJSONs, slice the ocap-rt SVG into per-class layers, optimize tiles (WebP/pngquant/oxipng), write `map.json` + `source.json`, verify. Output lands at `<Arma3>\ramet_output\{world}\`.
4. Bails on any verify error before deploying.

Re-runnable: orchestrate is idempotent per world. To redo just one:
```
docker run --rm -v <Arma3>:/work -e RAMET_ARMA_ROOT=/work ramet-postprocess:latest --world altis
```

## 6. Deploy

### 6a. Local planner (same machine)

```
batch\04_deploy.bat
```

Copies `<Arma3>\ramet_output\{world}\` into `JSOC-OPS-Warlords\server\warlords\map_tiles\{world}\`. Add `--prune-legacy` to wipe planner-side maps that lack a RAMET `map.json` (verify first with `--dry-run`).

### 6b. Remote planner (SFTP)

```
batch\05_zip_for_upload.bat                       :: per-world zips
batch\05_zip_for_upload.bat --bundle              :: single bundle zip
batch\05_zip_for_upload.bat --world altis         :: specific world(s)
```

Writes to `<Arma3>\ramet_output\_zips\`. SFTP/SCP those zips to the planner host and extract under `server/warlords/map_tiles/` — each zip contains a top-level `{world}/` dir.

## Partial-output handling

- If a map fails the grad_meh pass (encrypted ebo / unsupported), step 1 logs the failure to `ramet_state/ramet_bulk.log`; step 5 emits a manifest with `"source": "ocap"` and no `vectorSource`. Planner hides the vector overlay toggles for that map.
- Same in reverse if a map only has grad_meh output.
- Manifest declares only what was produced; the planner renders only what's declared. No client-side fallback logic.

## Troubleshooting

- "world mismatch" in `ramet_bulk.log` → the loop tried to process world X but Arma loaded world Y. Re-launch Arma with that world (or accept the skip; remaining worlds still process).
- `diag_exportTerrainSVG` missing → you're on main branch, not diag. Steam beta selection.
- Docker build OOM (ocap-rt render) → set `OCAP_RENDER_DOCKER_MEMORY=24g` (default 48g) before running step 3.
- "tippecanoe not found" inside orchestrate → the `ramet-postprocess` image is stale. Rebuild: `docker build --no-cache -t ramet-postprocess:latest -f tools\Dockerfile .` from RAMET root, or rerun `03_postprocess.bat`.
