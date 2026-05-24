/*
 * Author: Root
 * Description: Main-menu single-source-of-truth picker.
 *              Closes any auto-opened grad_meh/ocap_renderterrain main dialog,
 *              detects which mods are available, and delegates back to the
 *              chosen mod's own export dialog. The operator gets ONE prompt
 *              regardless of which mods are loaded or which branch is active.
 *
 * Called from RscDisplayMain.ControlsBackground.zzz_ramet_onLoadHandler.onLoad
 * (auto on main menu) and from CfgMainMenuSpotlight.ramet_bulk.action (tile).
 *
 * Public: No
 */

// Guard against running twice (auto-open + manual tile click).
if (!isNil "ramet_mainMenuPickerActive" && {ramet_mainMenuPickerActive}) exitWith {};
ramet_mainMenuPickerActive = true;

// Let grad_meh / ocap_renderterrain finish their own onLoad first, then take over.
sleep 0.5;

// Close whichever mod dialog auto-opened on top of the main menu.
private _autoClasses = ["grad_meh_main", "ocap_renderterrain_main"];
{
    private _disp = uiNamespace getVariable [_x, displayNull];
    if (!isNull _disp) then { _disp closeDisplay 0 };
} forEach _autoClasses;
closeDialog 0;

private _gradLoaded = isClass (configFile >> "CfgPatches" >> "grad_meh_main");
private _ocapLoaded = isClass (configFile >> "CfgPatches" >> "ocap_renderterrain_exporter");
private _isDiag = !isNil "diag_exportTerrainSVG";

if (!_gradLoaded && !_ocapLoaded) exitWith {
    hint "RAMET: neither grad_meh nor ocap_renderterrain mod is loaded.";
    ramet_mainMenuPickerActive = false;
};

private _branchLine = if (_isDiag) then { "Branch: DIAGNOSTIC (OCAP available)" } else { "Branch: MAIN/STABLE (grad_meh available)" };
private _msg = format [
    "Select bulk export mode.\n\n%1\n\n  • Grad_meh : main/stable branch\n  • OCAP     : diagnostic branch (uses diag_exportTerrainSVG)",
    _branchLine
];

[
    _msg,
    "RAMET — Bulk Export",
    {
        // YES = Grad_meh
        if (!isClass (configFile >> "CfgPatches" >> "grad_meh_main")) exitWith {
            hint "grad_meh not loaded — restart Arma with @grad_meh mod enabled.";
        };
        if (isNil "diag_exportTerrainSVG") then {
            // main branch, normal path — open grad_meh's own UI
            (findDisplay 0) createDisplay "grad_meh_main";
        } else {
            hint "WARN: running diagnostic branch — grad_meh works but stable branch is recommended.";
            (findDisplay 0) createDisplay "grad_meh_main";
        };
    },
    {
        // NO = OCAP
        if (!isClass (configFile >> "CfgPatches" >> "ocap_renderterrain_exporter")) exitWith {
            hint "ocap_renderterrain not loaded.";
        };
        if (isNil "diag_exportTerrainSVG") exitWith {
            hint "OCAP requires the Arma 3 DIAGNOSTIC branch (diag_exportTerrainSVG missing). Swap branches in Steam.";
        };
        (findDisplay 0) createDisplay "ocap_renderterrain_main";
    },
    "Grad_meh",
    "OCAP"
] call BIS_fnc_guiMessage;

ramet_mainMenuPickerActive = false;
