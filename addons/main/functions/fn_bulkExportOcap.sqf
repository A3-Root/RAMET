/*
 * Author: Root
 * Description: Bulk-export every world in worlds.txt via ocap-renderterrain.
 *              Wraps ocap-exporter/export_data.sqf in a FlatDevil-driven loop.
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
    private _r = ["ramet.bulk.next_world", ["ocap"]] call ramet_fnc_fdCall;
    _r params ["_ok", ["_value", []]];
    if (!_ok) exitWith {
        // bridge failure ends the queue: an empty world name stops the loop
        diag_log text format ["[RAMET ocap] ERROR next_world: %1", _r];
        ""
    };
    _value param [0, "", [""]]
};

private _markDone = {
    params ["_world", "_ok", ["_err", ""]];
    private _r = ["ramet.bulk.mark_done", ["ocap", _world, _ok, _err]] call ramet_fnc_fdCall;
    if !(_r select 0) then {
        diag_log text format ["[RAMET ocap] ERROR mark_done %1: %2", _world, _r];
    };
};

private _log = {
    params ["_msg"];
    ["ramet.bulk.log_progress", [_msg]] call ramet_fnc_fdCall;
    diag_log text format ["[RAMET ocap] %1", _msg];
};

private _kickDocker = {
    params ["_world"];
    // fire-and-forget — the python side threads the work and returns immediately
    private _r = ["ramet.kickoff.run_docker", [_world]] call ramet_fnc_fdCall;
    if !(_r select 0) then {
        diag_log text format ["[RAMET ocap] ERROR run_docker %1: %2", _world, _r];
    };
};

[format ["bulk ocap export starting (worldName=%1)", worldName]] call _log;

if !([] call ramet_fnc_isDiagBuild) exitWith {
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

        // Vendored ocap_renderterrain exporter: fires the async export then blocks
        // until the done flag flips, matching the in-game bulk-export pattern.
        ocap_exporter_done = false;
        [] call ocap_renderterrain_fnc_exportCurrentWorld;
        waitUntil { sleep 2; missionNamespace getVariable ["ocap_exporter_done", false] };

        [_world] call _kickDocker;
        [_world, true, ""] call _markDone;
        [format ["finished %1", _world]] call _log;
    };
};

["bulk ocap export complete"] call _log;
endMission "END1";
