> **RAMET note:** this directory is native-source-only (C# solution for
> `MapExportExtension_x64.dll`, built via `dotnet publish` in `release.ps1`). The addon PBOs
> described below were absorbed into `@root_amet`'s `addons/a3me_main` + `addons/a3me_exporter`
> — see repo-root `CLAUDE.md`.

# GameMapStorage.Arma3

# How to export a map

For atlas.plan-ops.fr/maps.plan-ops.fr you may [create an issue to add a new map](https://github.com/jetelain/GameMapStorage.Arma3/issues/new?assignees=jetelain&labels=new+map&projects=&template=ask-for-a-new-arma-3-map.md&title=Add+new+map+%5Bname+of+the+map%5D) or export it your self and then ask for integration of the package.

See also [GameMapStorage documentation](https://github.com/jetelain/GameMapStorage/wiki)

## Create a layer package

A layer package is a zip file that can be imported into a GameMapStorage instance / atlas.plan-ops.fr

Note: You need a computer with at least 8 GB of memory (exporter will need up to 2GB to be added to game requirements).

1. Download Export 2.0 mod on Workshop : https://steamcommunity.com/sharedfiles/filedetails/?id=3243017194

2. Disable Battleye, Launch Arma3 with CBA_A3, ACE, the Export mod and all additonal mods required for map to export. 

3. Ensures that Arma 3 is full screen with 1920x1080 resolution, Format Auto, and Normal size UI.

4. Open Eden Editor, place any unit on map, ensures that difficulty is set to veteran (to avoid any marker on map), and launch mission

5. Open map, disable satellite view / textures, place cursor out of map surface, and hit key `Home` (Might be ↖, ◤, ⇱, Pos1, or something like that), "Taking screenshots..." should be displayed, and map should be moving

6. Wait for up to 10 minutes (Altis took 7 minutes on my computer) until "It's done" is displayed

7. Close game, open `%USERPROFILE%\Arma3MapExporter` with explorer, all data is ready.

8. Zip the content of the map directory (the zip should contains index.json, base.png and hires.png)

## Import on atlas.plan-ops.fr

Contact GrueArbre on [Discord](https://discord.gg/neyBGgV4v8), or [create a GitHub issue](https://github.com/jetelain/GameMapStorage.Arma3/issues/new?assignees=jetelain&labels=new+map&projects=&template=ask-for-a-new-arma-3-map.md&title=Add+new+map+%5Bname+of+the+map%5D).

Use a service such as [We Transfer](https://wetransfer.com/), or a Cloud Storage, if the file is too big for Discord or gitHub.

## Import on a custom GameMapStorage instance

In the Admin Menu, go to "Layers". On the page click on "Create From Package", select the file and validate.

You will need to edit the layer to make it default if it's the first layer of the map.