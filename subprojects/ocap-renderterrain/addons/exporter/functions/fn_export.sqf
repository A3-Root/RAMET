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

				private _extensionStatus = {
					params [["_callResult", ""]];
					private _text = str _callResult;
					private _status = "unknown";
					if (((_text find """status""") >= 0) && {(_text find """queued""") >= 0}) then { _status = "queued"; };
					if (((_text find """status""") >= 0) && {(_text find """building""") >= 0}) then { _status = "building"; };
					if (((_text find """status""") >= 0) && {(_text find """running""") >= 0}) then { _status = "running"; };
					if (((_text find """status""") >= 0) && {(_text find """done""") >= 0}) then { _status = "done"; };
					if (((_text find """status""") >= 0) && {(_text find """error""") >= 0}) then { _status = "error"; };
					_status
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
					private _startResult = "archangel" callExtension ["ocap_renderterrain.process_world", [_currentWorld]];
					private _processStatus = [_startResult] call _extensionStatus;
					if (_processStatus isEqualTo "error") then {
						[_currentWorld, "process_docker", "canceled"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
						[_currentWorld, str _startResult] call _reportError;
					} else {
						private _lastStatusResult = _startResult;
						waitUntil {
							sleep 5;
							private _statusResult = "archangel" callExtension ["ocap_renderterrain.get_status", [_currentWorld]];
							_lastStatusResult = _statusResult;
							_processStatus = [_statusResult] call _extensionStatus;
							_processStatus in ["done", "error"]
						};
						if (_processStatus isEqualTo "done") then {
							[_currentWorld, "process_docker", "done"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
						} else {
							[_currentWorld, "process_docker", "canceled"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
							[_currentWorld, str _lastStatusResult] call _reportError;
						};
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
					[_maps select _nextIndex] call (uiNamespace getVariable "ocap_renderterrain_fnc_startMission");
				} else {
					uiNamespace setVariable ["ocap_renderterrain_maps", nil];
					uiNamespace setVariable ["ocap_renderterrain_index", nil];
					diag_log "[OCAP RenderTerrain]: Bulk export finished";
					systemChat "[OCAP RenderTerrain]: Bulk export finished";
				};

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

failMission "END1";
