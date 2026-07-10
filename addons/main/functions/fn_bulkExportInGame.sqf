/*
 * Author: Root
 * Description: Bulk-export every world in worlds.txt via the bundled map exporter (GMS).
 *              Drives the bundled in-game export function directly per world,
 *              polls the C# extension status until Done/Error, advances the queue.
 *              Requires CBA + RAMET + flatdevil_x64.dll in Arma root.
 *
 * Public: No
 *
 * Usage:
 *   [] spawn ramet_fnc_bulkExportInGame;
 */

#include "..\script_component.hpp"

if (!isServer) exitWith {};

private _next = {
    private _r = ["ramet.bulk.next_world", ["ingame"]] call ramet_fnc_fdCall;
    _r params ["_ok", ["_value", []]];
    if (!_ok) exitWith {
        // bridge failure ends the queue: an empty world name stops the loop
        diag_log text format ["[RAMET ingame] ERROR next_world: %1", _r];
        ""
    };
    _value param [0, "", [""]]
};

private _markDone = {
    params ["_world", "_ok", ["_err", ""]];
    private _r = ["ramet.bulk.mark_done", ["ingame", _world, _ok, _err]] call ramet_fnc_fdCall;
    if !(_r select 0) then {
        diag_log text format ["[RAMET ingame] ERROR mark_done %1: %2", _world, _r];
    };
};

private _log = {
    params ["_msg"];
    ["ramet.bulk.log_progress", [_msg]] call ramet_fnc_fdCall;
    diag_log text format ["[RAMET ingame] %1", _msg];
};

if (isNil "root_amet_a3me_export") exitWith {
    ["ERROR: bundled exporter callback is unavailable"] call _log;
};

[format ["bulk ingame export starting (worldName=%1)", worldName]] call _log;

while {true} do {
    private _world = call _next;
    if (_world == "") exitWith { ["world list exhausted"] call _log; };
    if (toLower _world != toLower worldName) then {
        [format ["WARN: queued '%1' but world is '%2' — skipping", _world, worldName]] call _log;
        [_world, false, "world mismatch"] call _markDone;
    } else {
        [format ["exporting %1", _world]] call _log;

        // Direct SQF kick (primary path; synthetic Home keypress fallback only).
        [] spawn root_amet_a3me_export;

        // Poll status from the C# extension until terminal state.
        private _terminal = false;
        private _lastStatus = "";
        private _startTs = diag_tickTime;
        while {!_terminal} do {
            sleep 2;
            private _status = ("mapExportExtension" callExtension ["status", []]) param [0, "idle", [""]];
            if (_status != _lastStatus) then {
                [format ["status: %1", _status]] call _log;
                _lastStatus = _status;
            };
            if (_status == "done") then { _terminal = true; };
            if (_status find "error" == 0) then { _terminal = true; };
            // Safety timeout: 30 minutes / world.
            if (diag_tickTime - _startTs > 1800) exitWith {
                [format ["TIMEOUT exporting %1", _world]] call _log;
                _terminal = true;
                _lastStatus = "error:timeout";
            };
        };

        if (_lastStatus == "done") then {
            [_world, true, ""] call _markDone;
            [format ["finished %1", _world]] call _log;
        } else {
            [_world, false, _lastStatus] call _markDone;
            [format ["FAILED %1 (%2)", _world, _lastStatus]] call _log;
        };
    };
};

private _r = ["ramet.bulk.export_summary", ["ingame"]] call ramet_fnc_fdCall;
_r params ["_ok", ["_summary", []]];
if (!_ok) then {
    diag_log text format ["[RAMET ingame] ERROR export_summary: %1", _r];
};
_summary params [["_total", 0, [0]], ["_skipped", 0, [0]], ["_names", "", [""]]];
[format ["bulk ingame export complete — %1 processed, %2 skipped", _total, _skipped]] call _log;
if (_skipped > 0) then {
    [format ["skipped maps: %1", _names]] call _log;
};
["END1", true, false, false] call BIS_fnc_endMission;
