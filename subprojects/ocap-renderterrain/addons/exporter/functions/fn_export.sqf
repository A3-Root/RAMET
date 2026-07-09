/*
 * Bulk-export OCAP render terrain source data for one or more worlds.
 *
 * Arguments:
 * 0: World class names to export <ARRAY>
 * 8: Run Docker processing in-game <BOOL> (optional, default true)
 *
 * Example:
 * [["Stratis", "Altis"]] call ocap_renderterrain_fnc_export;
 */

params [
	["_maps", [], [[]]],
	["_exportSat", true, [true]],
	["_exportTopo", true, [true]],
	["_exportBakedTopo", true, [true]],
	["_exportHouses", true, [true]],
	["_exportPreviewImg", true, [true]],
	["_exportMeta", true, [true]],
	["_exportDem", true, [true]],
	["_processDockerInGame", true, [true]]
];

if (_maps isEqualTo []) then {
	_maps = [worldName];
};

uiNamespace setVariable ["ocap_renderterrain_maps", +_maps];
uiNamespace setVariable ["ocap_renderterrain_index", 0];
uiNamespace setVariable ["ocap_renderterrain_progress", []];
uiNamespace setVariable ["ocap_renderterrain_errors", []];
uiNamespace setVariable ["ocap_renderterrain_processDockerInGame", _processDockerInGame];

disableSerialization;

uiNamespace setVariable ["ocap_renderterrain_fnc_startMission", {
	params [["_world", worldName]];

	playScriptedMission [
		_world,
		{
			[] spawn {
				private _maps = uiNamespace getVariable ["ocap_renderterrain_maps", []];
				private _index = uiNamespace getVariable ["ocap_renderterrain_index", 0];
				private _currentWorld = _maps param [_index, worldName, [""]];

				waitUntil { sleep 1; time > 0 };
				diag_log format ["[OCAP RenderTerrain]: Exporting %1 (%2/%3)", _currentWorld, _index + 1, count _maps];
				systemChat format ["[OCAP RenderTerrain]: Exporting %1 (%2/%3)", _currentWorld, _index + 1, count _maps];
				waitUntil { !isNull findDisplay 46 };
				private _loadingDisplay = (findDisplay 46) createDisplay "ocap_renderterrain_loading";
				_loadingDisplay setVariable ["ocap_renderterrain_worlds", _maps];
				[_loadingDisplay] call (uiNamespace getVariable "ocap_renderterrain_fnc_loading_redraw");

				private _reportError = {
					params [["_world", ""], ["_error", ""]];
					diag_log format ["[OCAP RenderTerrain]: Error while exporting %1: %2", _world, _error];
					private _errors = uiNamespace getVariable ["ocap_renderterrain_errors", []];
					_errors = [_errors, _world, _error, true] call (uiNamespace getVariable "BIS_fnc_setToPairs");
					uiNamespace setVariable ["ocap_renderterrain_errors", _errors];
				};

				[_currentWorld, "load_world", "running"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
				[_currentWorld, "load_world", "done"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");

				[_currentWorld, "export_source", "running"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
				ocap_exporter_done = false;
				[] call ocap_renderterrain_fnc_exportCurrentWorld;
				waitUntil { sleep 2; missionNamespace getVariable ["ocap_exporter_done", false] };
				[_currentWorld, "export_source", "done"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");

				private _processDockerInGame = uiNamespace getVariable ["ocap_renderterrain_processDockerInGame", true];
				if (_processDockerInGame) then {
					[_currentWorld, "process_docker", "running"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");

					// Listen for the python job thread's status pushes before starting
					// the job, so no transition can be missed. The python side lowercases
					// job keys, hence the toLower compare.
					private _cbKey = toLower _currentWorld;
					missionNamespace setVariable ["ocap_renderterrain_jobResult", nil];
					private _ehId = addMissionEventHandler ["ExtensionCallback", {
						params ["_name", "_function", "_data"];
						if (_name isEqualTo "flatdevil" && {_function isEqualTo "ocap_renderterrain.status"}) then {
							(parseSimpleArray _data) params [["_world", ""], ["_status", ""], ["_error", ""], ["_output", ""]];
							if (_status in ["done", "error"]) then {
								missionNamespace setVariable ["ocap_renderterrain_jobResult", [_world, _status, _error]];
							};
						};
					}];

					private _start = ["ocap_renderterrain.process_world", [_currentWorld]] call ocap_renderterrain_fnc_fdCall;
					if (_start select 0) then {
						// Job accepted — wait for the terminal push from the job thread.
						waitUntil {
							sleep 1;
							private _result = missionNamespace getVariable ["ocap_renderterrain_jobResult", []];
							(_result param [0, ""]) isEqualTo _cbKey && {(_result param [1, ""]) in ["done", "error"]}
						};
						removeMissionEventHandler ["ExtensionCallback", _ehId];
						(missionNamespace getVariable ["ocap_renderterrain_jobResult", []]) params ["", "_status", ["_error", ""]];
						if (_status isEqualTo "done") then {
							[_currentWorld, "process_docker", "done"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
						} else {
							[_currentWorld, "process_docker", "canceled"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
							[_currentWorld, _error] call _reportError;
						};
					} else {
						removeMissionEventHandler ["ExtensionCallback", _ehId];
						[_currentWorld, "process_docker", "canceled"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
						[_currentWorld, str _start] call _reportError;
					};
				} else {
					[_currentWorld, "process_docker", "canceled"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
					diag_log format ["[OCAP RenderTerrain]: Skipping Docker processing for %1", _currentWorld];
					systemChat format ["[OCAP RenderTerrain]: Skipping Docker processing for %1", _currentWorld];
				};

				private _nextIndex = _index + 1;
				uiNamespace setVariable ["ocap_renderterrain_index", _nextIndex];

				private _zero = findDisplay 0;
				{
					if (_x != _zero) then {
						_x closeDisplay 1;
					};
				} forEach allDisplays;

				if (_nextIndex < count _maps) then {
					uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];
					[_maps select _nextIndex] call (uiNamespace getVariable "ocap_renderterrain_fnc_startMission");
				} else {
					uiNamespace setVariable ["ocap_renderterrain_maps", nil];
					uiNamespace setVariable ["ocap_renderterrain_index", nil];
					diag_log "[OCAP RenderTerrain]: Bulk export finished";
					systemChat "[OCAP RenderTerrain]: Bulk export finished";
				};

				uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];
				failMission "END1";
			};
		},
		missionConfigFile,
		true
	];
}];

[_maps select 0] call (uiNamespace getVariable "ocap_renderterrain_fnc_startMission");

private _zero = findDisplay 0;
{
	if (_x != _zero) then {
		_x closeDisplay 1;
	};
} forEach allDisplays;

uiNamespace setVariable ["ramet_ingame_autoCloseDebriefing", true];
failMission "END1";
