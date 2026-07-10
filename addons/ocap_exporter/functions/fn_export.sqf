/*
 * Bulk-export OCAP render terrain source data for one or more worlds.
 *
 * Source export only — post-processing always runs afterward via
 * batch\03_postprocess.bat / .sh, never triggered from inside Arma.
 *
 * Arguments:
 * 0: World class names to export <ARRAY>
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
	["_exportDem", true, [true]]
];

if (_maps isEqualTo []) then {
	_maps = [worldName];
};

uiNamespace setVariable ["ocap_renderterrain_maps", +_maps];
uiNamespace setVariable ["ocap_renderterrain_index", 0];
uiNamespace setVariable ["ocap_renderterrain_progress", []];
uiNamespace setVariable ["ocap_renderterrain_errors", []];

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

				[_currentWorld, "load_world", "running"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
				[_currentWorld, "load_world", "done"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");

				[_currentWorld, "export_source", "running"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");
				ocap_exporter_done = false;
				[] call ocap_renderterrain_fnc_exportCurrentWorld;
				waitUntil { sleep 2; missionNamespace getVariable ["ocap_exporter_done", false] };
				[_currentWorld, "export_source", "done"] call (uiNamespace getVariable "ocap_renderterrain_fnc_updateProgress");

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
