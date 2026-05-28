/*
 * Author: Root
 * Description: onUnLoad handler for ramet_ingame_main dialog.
 *              Collects selected worlds from map tiles and kicks off
 *              ramet_fnc_ingameExport. Mirrors grad_meh_fnc_main_onUnLoad.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 * 1: Exit code (1 = Export, 0 = Cancel) <NUMBER>
 *
 * Public: No
 */

params ["_display", "_exitCode"];

private _maps = [];
{
    if (_x getVariable ["grad_meh_selected", false]) then {
        private _worldName = _x getVariable ["grad_meh_worldName", ""];
        if (_worldName != "") then { _maps pushBack _worldName; };
    };
} forEach (allControls _display);

uiNamespace setVariable ["ramet_ingame_selectedMaps", _maps];

if (_exitCode != 1) exitWith {};

if (_maps isEqualTo []) exitWith {
    (displayParent _display) spawn { _this createDisplay "ramet_ingame_main"; };
};

[_maps] call ramet_fnc_ingameExport;
