/*
 * Author: Root (adapted from DerZade / grad_meh)
 * onUnLoad handler for ramet_ingame_main dialog.
 * Collects selected worlds and triggers ingame export, or re-opens on empty selection.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 * 1: Exit code (1 = OK, 0 = Cancel) <NUMBER>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

diag_log format ["[RAMET ingame] onUnLoad fired — exitCode=%1", _exitCode];

private _contentGrp = _display displayCtrl IDC_DIALOG_CONTENT;
diag_log format ["[RAMET ingame] contentGrp=%1 controls=%2", _contentGrp, count (allControls _contentGrp)];

private _maps = [];
{
	private _selected = _x getVariable ["ramet_ingame_selected", false];
	if (_selected) then {
		_maps pushBack (_x getVariable ["ramet_ingame_worldName", ""]);
	};
} forEach (allControls _contentGrp);

uiNamespace setVariable ["ramet_ingame_selectedMaps", _maps];
diag_log format ["[RAMET ingame] maps collected=%1", _maps];

if (_exitCode isEqualTo 1) then {
	if (count _maps isEqualTo 0) then {
		(displayParent _display) spawn { _this createDisplay "ramet_ingame_main"; };
	} else {
		[_maps] call (uiNamespace getVariable "root_amet_fnc_ingameExport");
	};
} else {
	[displayParent _display] spawn {
		params ["_parent"];

		if (isNil "BIS_fnc_guiMessage") exitWith {
			_parent createDisplay "ramet_ingame_main";
		};

		private _result = [
			"Are you sure you want to quit the In-Game Export menu?",
			"Quit In-Game Export",
			true,
			true,
			_parent
		] call (uiNamespace getVariable "BIS_fnc_guiMessage");

		if (_result) exitWith {};

		_parent createDisplay "ramet_ingame_main";
	};
};
