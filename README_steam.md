[h1]RAMET — Root's Arma Map Export Tool[/h1]

RAMET is a single, end-to-end pipeline for exporting Arma 3 terrain into planner-ready raster and vector tile sets. It absorbs three export methods (grad_meh, ocap-renderterrain, and an in-game GMS exporter) plus a vendored, RAMET-patched Intercept into one [i][b]@root_amet[/b][/i] mod, post-processes the raw exports through Docker, and hands off a unified [i][b]map.json[/b][/i] tile tree ready for a web map planner.

[hr]
[h2]Important Notes[/h2]

[list]
[*][b]Source-available, build-your-own DLLs:[/b] this Workshop item ships the full source for all three native export extensions (grad_meh, ocap_exporter, arma3MapExporter) alongside the mod itself. If a prebuilt [i][b].dll[/b][/i] for your platform isn't already present, build it with the included [i][b]release.ps1[/b][/i] (Windows) / [i][b]release.sh[/b][/i] (Linux) scripts. 
[*][b]HEMTT required to build:[/b] rebuilding from source requires [url=https://github.com/BrettMayson/HEMTT]HEMTT[/url] on [i][b]PATH[/i][/b]. [i][b]release.ps1[/i][/b] / [i][b]release.sh[/i][/b] call [i][b]hemtt check[/i][/b] + [i][b]hemtt release[/i][/b] directly — without it, nothing builds.
[*][b]Docker required for post-processing:[/b] turning an in-game export into finished tiles ([i][b]batch\03_postprocess.bat[/i][/b] / [i][b].sh[/i][/b]) runs entirely in Docker (tippecanoe, pmtiles, cwebp, pngquant, oxipng). No host install of those tools is needed, but Docker itself must be running.
[*][b]Windows is the fully supported platform end to end:[/b] in-game export (grad_meh, OCAP, GMS) only works against a Windows Arma 3 client — Proton included, since it still runs the same Windows client. Linux is supported for the post-process/deploy/zip steps and for cross-compiling the ocap_exporter DLL; grad_meh and arma3MapExporter DLLs always require a Windows toolchain.
[*][b]Not a finished gameplay mod:[/b] this is an export/tooling pipeline for mission and community planner maintainers, not a combat or gameplay addition.
[/list]

[hr]
[h2]What It Does[/h2]

[list]
[*] Exports Arma 3 terrain via three methods for different fidelity/viewpoint tradeoffs: grad_meh (satellite + vector), OCAP-renderterrain (tile pyramids), and an in-game GMS aerial capture.
[*] Auto-detects stable vs. diagnostic Arma binaries and adapts which spotlight tiles show and how the vendored Intercept host boots.
[*] Drives exports through in-game spotlight UIs or an unattended batch queue ([i][b]batch\worlds.txt[/i][/b]), resumable across crashes and branch swaps.
[*] Post-processes raw exports into a unified [i][b]ramet_output/{world}/[/i][/b] tile tree (PMTiles, WebP raster pyramids, sliced SVG layers, DEM) entirely inside Docker.
[*] Deploys or zips the finished tile tree for a local or remote web map planner.
[/list]

[hr]
[h2]Credits[/h2]
[list]
[*] [b]Root[/b] - Author
[*][url=https://github.com/indig0fox/ocap-renderterrain][b]IndigoFox[/b][/url] - OCAP-RenderTerrain
[*][url=https://github.com/intercept/intercept][b]IDI-Systems[/b][/url] - Intercept
[*][url=https://github.com/gruppe-adler/grad_meh][b]Gruppe Adler[/b][/url] - Grad Meh
[*][url=https://github.com/jetelain/GameMapStorage.Arma3][b]Julien Etelain[/b][/url] - Game Map Storage Arma 3
[/list]

[hr]
[h2]Links[/h2]
[url=https://github.com/A3-Root/RAMET][img]https://i.imgur.com/lPLHihO.gif[/img][/url]
[url=https://discord.gg/77th-jsoc-official][img]https://i.imgur.com/8B7UcQ2.gif[/img][/url]

[hr]
[h2]License[/h2]
The combined project is distributed under the [b]Arma Public License Share Alike (APL-SA)[/b].

===============================================================================
[h3]PROJECT LICENSE (Arma Public License Share Alike - APL-SA)[/h3]
===============================================================================
Copyright (C) 2026 A3-Root (aka xMidnightSnowx)

With this licence you are free to adapt (i.e. modify, rework or update) and 
share (i.e. copy, distribute or transmit) the material under the following conditions:
[list]
[*][b]Attribution:[/b] You must attribute the material in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the material).
[*][b]Noncommercial:[/b] You may not use this material for any commercial purposes.
[*][b]Arma Only:[/b] You may not convert or adapt this material to be used in other games than Arma.
[*][b]Share Alike:[/b] If you adapt, or build upon this material, you may distribute the resulting material only under the same license.
[/list]
Full license text and legal provisions can be found at: 
https://www.bohemia.net/community/licenses/arma-public-license-share-alike

===============================================================================
[h3]ORIGINAL COMPONENTS & THIRD-PARTY NOTICES[/h3]
===============================================================================

1. APL-SA LICENSED COMPONENTS (SHARE-ALIKE REQUIREMENT)
-------------------------------------------------------
This project incorporates components licensed under the APL-SA. Due to the 
Share Alike provisions, the combined project is distributed under the same terms:
[list][*]Copyright (C) 2023 IndigoFox[/list]

2. STANDALONE MIT LICENSED COMPONENTS
-------------------------------------------------------
The following external components are originally licensed under the MIT License. 
They are fully compatible with permissive reuse and are included here under 
the combined APL-SA project distribution:
[list]
[*]Intercept (Copyright (C) 2016 International Development and Integration Systems, LLC (IDI-Systems) for Intercept)
[*]Grad_Meh (Copyright (C) 2020 Gruppe Adler)
[*]GameMapStorage (Copyright (C) 2024 Julien Etelain)
[/list]