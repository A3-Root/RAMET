/*
 * Author: Root
 * Description: Bulk-export every world in worlds.txt via ocap-renderterrain.
 *              Wraps ocap-exporter/export_data.sqf in an Archangel-driven loop.
 *              Requires Arma diagnostic branch (diag_exportTerrainSVG).
 *
 * Public: No
 *
 * Usage:
 *   [] spawn ramet_fnc_bulkExportOcap;
 */

#include "..\script_component.hpp"

if (!isServer) exitWith {};

private _next = {
    private _r = "archangel" callExtension ["ramet.bulk.next_world", ["ocap"]];
    _r param [0, "", [""]]
};

private _markDone = {
    params ["_world", "_ok", ["_err", ""]];
    "archangel" callExtension ["ramet.bulk.mark_done", ["ocap", _world, str _ok, _err]];
};

private _log = {
    params ["_msg"];
    "archangel" callExtension ["ramet.bulk.log_progress", [_msg]];
    diag_log text format ["[RAMET ocap] %1", _msg];
};

private _kickDocker = {
    params ["_world"];
    // fire-and-forget — kickoff returns immediately
    "archangel" callExtension ["ramet.kickoff.run_docker", [_world]];
};

[format ["bulk ocap export starting (worldName=%1)", worldName]] call _log;

if (isNil "diag_exportTerrainSVG") exitWith {
    ["ERROR: diag_exportTerrainSVG not available — must run on Arma diagnostic branch"] call _log;
};

while {true} do {
    private _world = call _next;
    if (_world == "") exitWith { ["world list exhausted"] call _log; };
    if (toLower _world != toLower worldName) then {
        [format ["WARN: queued '%1' but world is '%2' — skipping", _world, worldName]] call _log;
        [_world, false, "world mismatch"] call _markDone;
    } else {
        [format ["exporting %1", _world]] call _log;

        // ocap-exporter's export_data.sqf calls diag_exportTerrainSVG + the exporter extension.
        // It blocks until done. Path resolved via @ocap_renderterrain mod load.
        private _exportScript = "\z\ocap_exporter\addons\exporter\export_data.sqf";
        [] call (compile preprocessFileLineNumbers _exportScript);

        [_world] call _kickDocker;
        [_world, true, ""] call _markDone;
        [format ["finished %1", _world]] call _log;
    };
};

["bulk ocap export complete"] call _log;
endMission "END1";
