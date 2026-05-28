/*
 * Author: Root
 * Description: onUnLoad handler for ramet_ingame_main dialog.
 *              Collects selected worlds and kicks off ramet_fnc_ingameExport.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 * 1: Exit code (1 = Export, 0 = Cancel) <NUMBER>
 *
 * Public: No
 */

params ["_display", "_exitCode"];

if (_exitCode != 1) exitWith {};

private _lb = _display displayCtrl 1010;
private _selected = [];

for "_i" from 0 to (lbSize _lb - 1) do {
    if (_lb lbIsSelected _i) then {
        _selected pushBack (_lb lbData _i);
    };
};

uiNamespace setVariable ["ramet_ingame_selectedMaps", _selected];

if (_selected isEqualTo []) exitWith {
    (displayParent _display) spawn { _this createDisplay "ramet_ingame_main"; };
};

[_selected] call ramet_fnc_ingameExport;
