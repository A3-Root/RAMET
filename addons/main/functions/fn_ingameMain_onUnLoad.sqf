/*
 * Author: Root (adapted from DerZade / grad_meh)
 * onUnLoad handler for the ramet_ingame_main and ramet_all_main dialogs.
 * Collects selected worlds and starts the export, or re-opens on empty selection.
 *
 * ramet_all_main sets ramet_all_pickerMode on load, which switches the OK
 * branch from the GMS export alone to the full Grad_meh + GMS + OCAP queue.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 * 1: Exit code (1 = OK, 0 = Cancel) <NUMBER>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

private _allModes = uiNamespace getVariable ["ramet_all_pickerMode", false];
uiNamespace setVariable ["ramet_all_pickerMode", nil];
private _displayClass = ["ramet_ingame_main", "ramet_all_main"] select _allModes;

diag_log format ["[RAMET ingame] onUnLoad fired — exitCode=%1 allModes=%2", _exitCode, _allModes];

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
		[displayParent _display, _displayClass] spawn {
			params ["_parent", "_class"];
			_parent createDisplay _class;
		};
	} else {
		if (_allModes) then {
			// Multi-mode: ask each chosen exporter for its options first; the
			// last one of those starts the run.
			uiNamespace setVariable ["ramet_all_worlds", +_maps];
			uiNamespace setVariable ["ramet_all_optIndex", 0];
			[] call (uiNamespace getVariable "root_amet_fnc_allNextOptions");
		} else {
			[_maps] call (uiNamespace getVariable "root_amet_fnc_ingameExport");
		};
	};
} else {
	// User pressed Cancel: let the display close and fall back to whatever
	// opened it (the main menu). Re-creating the picker here is what used to
	// make Cancel look like it did nothing.
	if (_allModes) then {
		[] call (uiNamespace getVariable "root_amet_fnc_allAbort");
	};
	diag_log "[RAMET ingame] Cancelled — returning to the main menu.";
};
