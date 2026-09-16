/*
 * Author: Root
 * Description: Start the export mode the multi-mode queue is currently on,
 *              with the options collected for that mode.
 *
 * Public: No
 */
#include "..\script_component.hpp"

private _worlds = uiNamespace getVariable ["ramet_all_worlds", []];
private _modes = uiNamespace getVariable ["ramet_all_modes", []];
private _index = uiNamespace getVariable ["ramet_all_stageIndex", 0];

if (_worlds isEqualTo [] || {_index >= count _modes}) exitWith {
	uiNamespace setVariable ["ramet_all_active", false];
	diag_log "[RAMET all] Nothing left to start.";
};

private _mode = _modes select _index;
uiNamespace setVariable ["ramet_all_running", true];
// Each mode ends its worlds with a mission end; without this the debriefing
// screen would sit there waiting for a key press and stall the queue.
uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];

diag_log format ["[RAMET all] Stage %1/%2: %3 over %4", _index + 1, count _modes, _mode, _worlds];

private _skip = {
	params ["_reason"];
	diag_log format ["[RAMET all] %1 — skipping stage.", _reason];
	[] call (uiNamespace getVariable "root_amet_fnc_allChainNext");
};

switch (_mode) do {
	case "grad_meh": {
		private _fnc = uiNamespace getVariable ["grad_meh_fnc_export", nil];
		if (isNil "_fnc") exitWith { ["Grad_meh export function unavailable"] call _skip };
		private _opt = uiNamespace getVariable ["ramet_all_opt_grad_meh", [true, true, true, true, true, true, true]];
		uiNamespace setVariable ["grad_meh_selectedMaps", +_worlds];
		([_worlds] + _opt) call _fnc;
	};
	case "ingame": {
		private _fnc = uiNamespace getVariable ["root_amet_fnc_ingameExport", nil];
		if (isNil "_fnc") exitWith { ["In-game export function unavailable"] call _skip };
		private _opt = uiNamespace getVariable ["ramet_all_opt_ingame", [true, true]];
		// Read back by root_amet_a3me_export, which runs inside the mission.
		uiNamespace setVariable ["ramet_a3me_passes", _opt];
		uiNamespace setVariable ["ramet_ingame_selectedMaps", +_worlds];
		[_worlds] call _fnc;
	};
	case "ocap": {
		private _fnc = uiNamespace getVariable ["ocap_renderterrain_fnc_export", nil];
		if (isNil "_fnc") exitWith { ["OCAP export function unavailable"] call _skip };
		private _opt = uiNamespace getVariable ["ramet_all_opt_ocap", [true, true, true, true, true, true, true]];
		uiNamespace setVariable ["ocap_renderterrain_selectedMaps", +_worlds];
		([_worlds] + _opt) call _fnc;
	};
	default {
		[format ["Unknown stage '%1'", _mode]] call _skip;
	};
};
