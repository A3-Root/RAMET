[h1]RAMET — Root's Arma Map Export Tool[/h1]

RAMET exports Arma 3 terrains into raster and vector map tiles for a web map planner. It is a terrain export pipeline, not a gameplay mod.

[hr][h2]Pre-requisites[/h2]
[list]
[*][b]RAMET:[/b] Subscribe to this Workshop item and enable it in the Arma 3 launcher.
[*][b]CBA:[/b] Subscribe to and enable [url=https://steamcommunity.com/workshop/filedetails/?id=450814997]CBA_A3[/url]. Load it together with RAMET.
[*][b]FlatDevil:[/b] Download [url=https://github.com/A3-Root/FlatDevil]FlatDevil (Github)[/url] or [url=https://steamcommunity.com/workshop/filedetails/?id=450814997]FlatDevil (Steam Workshop)[/url]. Place [i][b]flatdevil_x64.dll[/b][/i] directly in the Arma 3 installation folder, next to [i][b]arma3_x64.exe[/b][/i], not inside the RAMET folder. Install Python 3.7 or newer and make sure [i][b]python[/b][/i] works in a new terminal.
[*][b]Terrain:[/b] Install or subscribe to the terrain you want to export, along with its required dependencies. Enable the terrain mod in the launcher with RAMET and CBA. A terrain that is only installed but not enabled will not be available to RAMET.[/list]
To find the Arma 3 installation folder in Steam, right-click [i]Arma 3 → Manage → Browse local files[/i]. After extracting a release, the folder should look like this:
[code]Arma 3\arma3_x64.exe
Arma 3\flatdevil_x64.dll
Arma 3\@root_amet\[/code]

[hr][h2]First Run[/h2]

[b]1. Enable the correct mods.[/b] In the Arma 3 launcher, enable [i][b]@root_amet[/b][/i], [i][b]@CBA_A3[/b][/i], the target terrains, and every dependency required by that terrain. Keep the terrain enabled while exporting.
[b]2. Pick the correct Arma branch.[/b]
[list][*][b]Stable/main branch:[/b] use [i][b]RAMET — Grad_meh export[/b][/i] for the regular satellite + vector export, or [i][b]RAMET — In-Game export (GMS)[/b][/i] for an in-game aerial export.
[*][b]Diagnostic/development branch:[/b] use [i][b]RAMET — OCAP export (diag)[/b][/i]. This requires the diagnostic executable; the stable executable does not provide the necessary OCAP export function.[/list]
[b]3. Open RAMET.[/b] Start Arma, select the RAMET spotlight/menu entry, choose the terrain(s), and begin the export. Large terrains can take a while. Do not close Arma or disable the terrain during the export.
[b]4. Post-process the result.[/b] Install and start [url=https://www.docker.com/products/docker-desktop/]Docker Desktop[/url]. Open a terminal in the Arma 3 installation folder and run:[code]@root_amet\batch\03_postprocess.bat[/code]

The finished tiles will be saved to [i][b]Arma 3\RAMET_Output\processed\{world}\[/b][/i]. Raw exporter data is kept under [i][b]Arma 3\RAMET_Output\raw\{world}\[/b][/i]. Docker provides the tile-processing tools, so you do not need to install tippecanoe, PMTiles, cwebp, pngquant, or oxipng separately.

To copy tiles into a local planner, use [i][b]@root_amet\batch\04_deploy.bat --planner-root "C:\path\to\your\planner\map_tiles"[/b][/i]. To create upload archives, use [i][b]@root_amet\batch\05_zip_for_upload.bat[/b][/i]; the archives will be found under [i][b]RAMET_Output\_zips\[/b][/i].

[hr][h2]Exporting a queue of terrains[/h2]
For automatic exports, edit [i][b]@root_amet\batch\worlds.txt[/b][/i]. Add one exact Arma [i]CfgWorlds[/i] class name per line, for example:[code]altis
stratis
my_custom_world
[/code]
Use the class name, not necessarily the display name shown in the launcher. The terrain mods for every listed world must be installed and enabled.
[list]
[*]On the stable branch, double-click [i][b]@root_amet\batch\01_export_grad_meh.bat[/b][/i].
[*]On the diagnostic branch, double-click [i][b]@root_amet\batch\02_export_ocap.bat[/b][/i].
[/list]
The scripts will launch the correct Arma executable and use FlatDevil to work through the queue. They can resume after crashes or restarts. Check [i][b]ramet_state\ramet_bulk.log[/b][/i] for progress, then run [i][b]03_postprocess.bat[/b][/i].

[hr][h2]Which exporter should I use?[/h2]
[table]
[tr][th]Exporter[/th][th]Branch[/th][th]Use it for[/th][/tr]
[tr][td]Grad_meh[/td][td]Stable/main[/td][td]Normal satellite + vector map data[/td][/tr]
[tr][td]OCAP RenderTerrain[/td][td]Diagnostic[/td][td]High-resolution OCAP terrain tile pyramids[/td][/tr]
[tr][td]In-Game/GMS[/td][td]Stable/main[/td][td]Aerial imagery captured through the game[/td][/tr]
[/table]
You can run more than one exporter for the same terrain. Post-processing will use whichever valid source data exists and will only include layers that were actually produced.

[hr][h2]Troubleshooting[/h2]
[list]
[*][b]RAMET is missing:[/b] confirm that the Workshop item is enabled, CBA is enabled, and the terrain and its dependencies are enabled. Restart Arma after changing mods.
[*][b]The terrain is missing from the picker:[/b] install and enable its terrain mod and dependencies. RAMET reads the terrains currently loaded by Arma.
[*][b]FlatDevil or Python errors:[/b] confirm that [i][b]flatdevil_x64.dll[/b][/i] is next to [i][b]arma3_x64.exe[/b][/i], Python 3.7+ is installed, and Arma was restarted after installing the DLL.
[*][b]OCAP reports that diag_exportTerrainSVG is missing:[/b] switch Steam to the Arma 3 diagnostic/development branch and run the diagnostic executable.
[*][b]Post-processing fails:[/b] start Docker Desktop and wait until it indicates Docker is running. If OCAP rendering already finished, retry with [i][b]@root_amet\batch\03_postprocess.bat --skip-ocap[/b][/i].
[/list]
[b]For the full beginner-friendly guide, batch details, output locations, and build instructions, read the [url=https://github.com/A3-Root/RAMET/blob/main/README.md]README.md on GitHub[/url].[/b]

[hr][h2]Important notes[/h2]

[list]
[*]Windows is the fully supported export platform. Linux/WSL can run post-processing, deployment, and zip steps. Building the Grad_meh and GMS native DLLs requires Windows tools.
[*]This Workshop item includes source for the native extensions. Rebuilding from source requires [url=https://github.com/BrettMayson/HEMTT]HEMTT[/url] and the toolchains described in [i][b]README.md[/b][/i]. The OCAP Go/cgo build also needs a Windows MinGW-w64/MSYS2 [i][b]gcc[/b][/i] on [i][b]PATH[/b][/i]. The provided DLLs should work without a local build. [i][b]release.ps1[/b][/i] can detect common install locations, start an installed-but-stopped Docker Desktop, and offer [i][b]winget[/b][/i] installs for supported missing tools.
[*]A normal [i][b]release.ps1 -Clean[/b][/i] run reuses the provided OCAP DLL. Use [i][b]release.ps1 -RebuildOcapDll -RebuildGradMehDll[/b][/i] only when you want to rebuild it; [i][b]-NoRebuildOcapDll -NoRebuildGradMehDll[/b][/i] skips these targets even when the DLL is missing.
[/list]

[hr][h2]Credits[/h2]
[list]
[*][b]Root[/b] — Author
[*][b]IndigoFox[/b] — [url=https://github.com/indig0fox/ocap-renderterrain]OCAP-RenderTerrain[/url]
[*][b]IDI-Systems[/b] — [url=https://github.com/intercept/intercept]Intercept[/url]
[*][b]Gruppe Adler[/b] — [url=https://github.com/gruppe-adler/grad_meh]Grad Meh[/url]
[*][b]Julien Etelain[/b] — [url=https://github.com/jetelain/GameMapStorage.Arma3]Game Map Storage Arma 3[/url]
[/list]

[hr][h2]Links[/h2]
[url=https://github.com/A3-Root/RAMET][img]https://i.imgur.com/lPLHihO.gif[/img][/url]
[url=https://discord.gg/qQXg8tB7gr][img]https://i.imgur.com/8B7UcQ2.gif[/img][/url]

[hr][h2]License[/h2]
The combined project is distributed under the [b]Arma Public License Share Alike (APL-SA)[/b]. See [url=https://www.bohemia.net/community/licenses/arma-public-license-share-alike]the full license[/url] and the included [i][b]LICENSE[/b][/i] file for legal terms and third-party notices.
