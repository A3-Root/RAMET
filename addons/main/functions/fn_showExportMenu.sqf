/*
 * Author: Root
 * Description: Two-option picker for the bulk exporter.
 *              Shows when both grad_meh and ocap-renderterrain mods are loaded
 *              and the operator needs to choose which export pass runs.
 *
 * Public: No
 *
 * Usage:
 *   [] call ramet_fnc_showExportMenu;
 */

#include "..\script_component.hpp"

if (!isNil "ramet_exportRunning" && {ramet_exportRunning}) exitWith {
    hint "RAMET: an export is already in progress.";
};

private _gradAvailable = !isNil "gradMehExportMap";
private _ocapAvailable = [] call ramet_fnc_isDiagBuild;
private _ingameAvailable = !isNil "root_amet_a3me_export";

private _msg = format [
    "Select bulk export mode.\n\nGrad_meh available: %1\nOCAP (diag) available: %2\nIn-Game (GMS) available: %3\n\n(In-Game export is run from the main-menu spotlight tile.)",
    ["NO — main branch needed", "YES"] select _gradAvailable,
    ["NO — diagnostic branch needed", "YES"] select _ocapAvailable,
    ["NO — bundled exporter unavailable", "YES"] select _ingameAvailable
];

[
    _msg,
    "RAMET — Bulk Export",
    {
        // YES button -> grad_meh
        if (isNil "gradMehExportMap") exitWith {
            hint "Grad_meh not loaded / not on main branch.";
        };
        ramet_exportRunning = true;
        [] spawn {
            [] call ramet_fnc_bulkExportGradMeh;
            ramet_exportRunning = false;
        };
    },
    {
        // NO button -> ocap
        if !([] call ramet_fnc_isDiagBuild) exitWith {
            hint "OCAP exporter not available — diagnostic branch required.";
        };
        ramet_exportRunning = true;
        [] spawn {
            [] call ramet_fnc_bulkExportOcap;
            ramet_exportRunning = false;
        };
    },
    "Grad_meh",
    "OCAP"
] call BIS_fnc_guiMessage;
