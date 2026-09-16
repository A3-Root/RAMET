# RAMET bulk export

This is the operator runbook for exporting one or more Arma 3 terrains and
turning the raw files into planner tiles.

## Before you start

Use Windows for the Arma export stages. Linux, WSL, and Git Bash can run the
post-processing, deployment, and zip stages. Proton still runs the Windows
Arma client, so it does not provide a separate Linux export path.

The Arma 3 folder must contain:

- `@root_amet`
- `@CBA_A3`
- `flatdevil_x64.dll` next to `arma3_x64.exe`
- Python 3.7 or newer available as `python`

Docker must be running before step 3. Python 3.7 or newer is required
for deployment and zip packaging.

The terrain mods also matter. Install every terrain listed in the queue and
its dependencies, then enable them in the Arma launcher with RAMET and CBA.
RAMET reads Arma's loaded `CfgWorldList`; an installed but disabled terrain
will not appear in the picker or export successfully.

If you are using a release archive, extract it into the Arma 3 folder. The
archive should create `Arma 3\@root_amet\`. Do not put the mod inside another
`@root_amet` folder.

## Choose an export method

The interactive path is the simplest way to export a few worlds. Start Arma
with the target terrain enabled and choose the matching spotlight:

| Export | Executable | Output |
| --- | --- | --- |
| Grad_meh | Main/stable | `RAMET_Output\raw\{world}\grad_meh\` |
| In-Game/GMS | Main/stable | `RAMET_Output\raw\{world}\a3me\` |
| OCAP RenderTerrain | Main/stable (64-bit) | `RAMET_Output\raw\{world}\ocap-rt\` |
| Multi-mode | Main/stable (64-bit) | whichever of the above you tick |

The **Multi-mode export** spotlight asks which exporters to run, which terrains
to run them over, and then each exporter's own options — after that it works
through them with no further input, so you can start it and walk away. The order
is always Grad_meh, then OCAP, then GMS: the screenshot-driven GMS pass is the
one most likely to misbehave unattended, so the other two finish first. It needs no `worlds.txt` entry; the picker's selection is the queue. Watch
the RPT log for `[RAMET all]` lines to see which stage is running. Cancel on any
of its screens abandons the run. Post-processing still runs separately, through
`03_postprocess.bat`.

All exporters run on the main branch. The OCAP terrain SVG is written by the
OCAP extension through the export function in the game executable; on the
diagnostic executable `diag_exportTerrainSVG` is the fallback. The picker only
lists worlds that Arma loaded.

## Queue several worlds

Edit `@root_amet\batch\worlds.txt` and put one exact `CfgWorlds` class name on
each line:

```text
altis
stratis
my_custom_world
```

Use the class name, not the display name. Comments beginning with `#` and
blank lines are ignored. Every listed world must come from a terrain mod that
is installed and enabled before the batch starts.

### Grad_meh queue

1. Switch to the main/stable Arma branch.
2. Close Arma if it is running.
3. Run this file from the Arma installation:

   ```bat
   @root_amet\batch\01_export_grad_meh.bat
   ```

The script resets the Grad_meh state file and launches `arma3_64.exe`. It
advances through the queue with FlatDevil. Raw output goes to
`Arma 3\RAMET_Output\raw\{world}\grad_meh\`.

### OCAP queue

1. Close Arma if it is running.
3. Run:

   ```bat
   @root_amet\batch\02_export_ocap.bat
   ```

The script launches `arma3_x64.exe` (or `arma3diag_x64.exe` when the normal
64-bit executable is missing). The OCAP stage keeps its own state,
so it can continue after a crash or a later relaunch. Raw output goes to
`Arma 3\RAMET_Output\raw\{world}\ocap-rt\` (`{world}.asc`, `{world}.svg` and
`map.json`). `03_postprocess.bat` renders the topo tiles into the same folder.

Progress and completion messages are written to
`Arma 3\ramet_state\ramet_bulk.log`.

## Post-process the exports

Run this from the Arma 3 folder after the export has finished:

```bat
@root_amet\batch\03_postprocess.bat
```

On Linux, WSL, or Git Bash, use:

```bash
@root_amet/batch/03_postprocess.sh
```

The script:

1. renders OCAP data when the OCAP renderer is present;
2. builds or reuses the `ramet-postprocess` Docker image;
3. merges the available source folders;
4. creates PMTiles, raster pyramids, SVG layers, and DEM output;
5. optimizes and verifies the result.

The final world directory is `Arma 3\RAMET_Output\processed\{world}\`.

`batch\render_worlds.txt` limits the worlds processed by the OCAP renderer.
Use one class name per line. Leave the file empty to process every discovered
world.

If OCAP has already rendered successfully and only the later stages need to be
rerun, use:

```bat
@root_amet\batch\03_postprocess.bat --skip-ocap
```

## Deploy or package the result

For a planner on the same machine, provide its `map_tiles` directory:

```bat
@root_amet\batch\04_deploy.bat --planner-root "C:\path\to\planner\map_tiles"
```

The shell equivalent is:

```bash
@root_amet/batch/04_deploy.sh --planner-root /path/to/planner/map_tiles
```

For a remote planner, create per-world archives:

```bat
@root_amet\batch\05_zip_for_upload.bat
```

Use `--bundle` to create one archive. The files go under
`Arma 3\RAMET_Output\_zips\`.

Both deploy and zip pack each world's loose raster pyramid
(`tiles\<variant>\<z>\<x>\<y>.<ext>`) into one `{world}\tiles.sqlite` for the
planner. The processed output in `RAMET_Output\processed\` is not changed. A
local deploy builds the pack before replacing the planner's world folder, so a
failed pack leaves the previous deployment in place. Add `--loose` to ship the
loose `tiles\` folders instead.

## Partial output

A world can contain data from any combination of Grad_meh, OCAP, and GMS.
`map.json` lists the layers that exist. Missing `vectorSource` or `svgLayers`
is expected when the corresponding export stage did not produce data.

`source.json` records the source directories used during the merge.

## Troubleshooting

**The batch script cannot find Arma.** Keep the script at
`Arma 3\@root_amet\batch\`. It finds the Arma folder by walking two levels up.

**The queue does not advance.** Check that `flatdevil_x64.dll` is next to
`arma3_x64.exe`, Python works in a new terminal, `@root_amet` is enabled, and
Arma has been restarted since FlatDevil was installed.

**A queued world is skipped.** Check the spelling and case of its `CfgWorlds`
class name. Confirm the terrain mod and its dependencies are enabled.

**The terrain SVG export is unavailable.** The OCAP extension needs the 64-bit
Windows executable. The heightmap is still exported. If a game update removed
the export function, run the diagnostic executable so the
`diag_exportTerrainSVG` fallback is used.

**Docker reports missing tools or cannot connect.** Start Docker Desktop and
wait for the daemon to become ready. The post-processing tools run inside the
Docker image; they do not need to be installed on the host.

**Deployment skips a world.** Confirm that
`RAMET_Output\processed\{world}\map.json` exists and that the planner path points to its
`map_tiles` directory.
