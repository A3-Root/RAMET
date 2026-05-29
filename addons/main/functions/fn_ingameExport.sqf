/*
 * Author: Root
 * Description: Bulk in-game export via arma3MapExporter (GMS).
 *              Follows the ocap_renderterrain_fnc_export pattern exactly:
 *              stores queue in uiNamespace (survives mission loads),
 *              uses playScriptedMission to load each world in sequence,
 *              waits for a3me_export to be available then spawns it,
 *              polls the C# extension status until terminal, advances the queue.
 *
 * Arguments:
 * 0: World class names to export <ARRAY>
 *
 * Public: No
 */

params [["_maps", [], [[]]]];

diag_log format ["[RAMET ingame] fn_ingameExport called — maps=%1", _maps];

if (_maps isEqualTo []) exitWith {};

uiNamespace setVariable ["ramet_ingame_maps", +_maps];
uiNamespace setVariable ["ramet_ingame_index", 0];
// Enable auto-close of RscDisplayDebriefing for the duration of bulk export.
// Cleared by ramet_ingame_fnc_closeDebriefing (XEH_preInit) after each close,
// and re-armed here for each subsequent world via BIS_fnc_endMission below.
uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];

disableSerialization;

// Registers a one-shot "Ended" mission EH for diagnostic logging and fallback close,
// then calls BIS_fnc_endMission. Both this EH and the RscDisplayDebriefing onLoad
// config patch attempt to close IDD 58 — whichever fires will be visible in RPT.
uiNamespace setVariable ["ramet_ingame_fnc_endWithDiag", {
	addMissionEventHandler ["Ended", {
		params ["_endType"];
		diag_log format ["[RAMET ingame]: [Ended EH] fired — endType=%1", _endType];
		diag_log format ["[RAMET ingame]: [Ended EH] allDisplays: %1", str allDisplays];
		private _nsKeys = ["GUI_displays", "IGUI_displays", "Loading_displays"];
		{
			private _nsDisplays = uiNamespace getVariable [_x, []];
			if (count _nsDisplays > 0) then {
				diag_log format ["[RAMET ingame]: [Ended EH] uiNamespace[%1]: %2", _x, str (_nsDisplays apply { ctrlIDD _x })];
			};
		} forEach _nsKeys;
		{
			if (ctrlIDD _x == 58) then {
				diag_log "[RAMET ingame]: [Ended EH] Found IDD 58 — closing";
				_x closeDisplay 1;
			};
		} forEach allDisplays;
	}];
	["END1", false, false, false] call BIS_fnc_endMission;
}];

uiNamespace setVariable ["ramet_ingame_fnc_startMission", {
	params [["_world", worldName]];

	playScriptedMission [
		_world,
		{
			[] spawn {
				private _maps = uiNamespace getVariable ["ramet_ingame_maps", []];
				private _index = uiNamespace getVariable ["ramet_ingame_index", 0];
				private _currentWorld = _maps param [_index, worldName, [""]];

				waitUntil { sleep 1; time > 0 };
				diag_log format ["[RAMET ingame]: Exporting %1 (%2/%3)", _currentWorld, _index + 1, count _maps];
				systemChat format ["[RAMET ingame]: Exporting %1 (%2/%3)", _currentWorld, _index + 1, count _maps];
				waitUntil { !isNull findDisplay 46 };

				// Wait for arma3MapExporter postInit to define a3me_export (up to 60 s).
				private _waitTs = diag_tickTime;
				waitUntil {
					sleep 1;
					(!isNil "a3me_export") || (diag_tickTime - _waitTs > 60)
				};

				if (isNil "a3me_export") exitWith {
					diag_log format ["[RAMET ingame]: ERROR — a3me_export undefined for %1. @arma3MapExporter not loaded?", _currentWorld];
					systemChat "[RAMET ingame]: ERROR — @arma3MapExporter not loaded, skipping world.";

					private _nextIndex = _index + 1;
					uiNamespace setVariable ["ramet_ingame_index", _nextIndex];

					private _zero = findDisplay 0;
					{ if (_x != _zero) then { _x closeDisplay 1; }; } forEach allDisplays;

					if (_nextIndex < count _maps) then {
						uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];
						[_maps select _nextIndex] call (uiNamespace getVariable "ramet_ingame_fnc_startMission");
					} else {
						uiNamespace setVariable ["ramet_ingame_maps", nil];
						uiNamespace setVariable ["ramet_ingame_index", nil];
						diag_log "[RAMET ingame]: Bulk export finished (with errors).";
						systemChat "[RAMET ingame]: Bulk export finished (with errors).";
					};

					call (uiNamespace getVariable "ramet_ingame_fnc_endWithDiag");
				};

				[] spawn a3me_export;

				// Poll C# extension status until terminal state.
				private _terminal = false;
				private _lastStatus = "";
				private _startTs = diag_tickTime;
				while {!_terminal} do {
					sleep 2;
					private _status = ("mapExportExtension" callExtension ["status", []]) param [0, "idle", [""]];
					if (_status != _lastStatus) then {
						diag_log format ["[RAMET ingame]: %1 status: %2", _currentWorld, _status];
						systemChat format ["[RAMET ingame]: %1: %2", _currentWorld, _status];
						_lastStatus = _status;
					};
					if (_status == "done") then { _terminal = true; };
					if (_status find "error" == 0) then { _terminal = true; };
					// Safety timeout: 30 min/world.
					if (diag_tickTime - _startTs > 1800) exitWith {
						diag_log format ["[RAMET ingame]: TIMEOUT %1", _currentWorld];
						_terminal = true;
						_lastStatus = "error:timeout";
					};
				};

				diag_log format ["[RAMET ingame]: %1 finished: %2", _currentWorld, _lastStatus];
				systemChat format ["[RAMET ingame]: %1: %2", _currentWorld, _lastStatus];

				private _nextIndex = _index + 1;
				uiNamespace setVariable ["ramet_ingame_index", _nextIndex];

				private _zero = findDisplay 0;
				{ if (_x != _zero) then { _x closeDisplay 1; }; } forEach allDisplays;

				if (_nextIndex < count _maps) then {
					uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];
					[_maps select _nextIndex] call (uiNamespace getVariable "ramet_ingame_fnc_startMission");
				} else {
					uiNamespace setVariable ["ramet_ingame_maps", nil];
					uiNamespace setVariable ["ramet_ingame_index", nil];
					diag_log "[RAMET ingame]: Bulk export complete.";
					systemChat "[RAMET ingame]: Bulk export complete.";
				};

				call (uiNamespace getVariable "ramet_ingame_fnc_endWithDiag");
			};
		},
		missionConfigFile,
		true
	];
}];

[_maps select 0] call (uiNamespace getVariable "ramet_ingame_fnc_startMission");

private _zero = findDisplay 0;
{ if (_x != _zero) then { _x closeDisplay 1; }; } forEach allDisplays;

call (uiNamespace getVariable "ramet_ingame_fnc_endWithDiag");
