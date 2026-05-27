/*
 * Author: Root
 * Description: Bulk-export every world in worlds.txt via GMS (arma3MapExporter).
 *              Drives the existing `a3me_export` SQF function directly per world,
 *              polls the C# extension status until Done/Error, advances the queue.
 *              Requires @arma3MapExporter + CBA + Archangel + RAMET.
 *
 * Public: No
 *
 * Usage:
 *   [] spawn ramet_fnc_bulkExportInGame;
 */

#include "..\script_component.hpp"

if (!isServer) exitWith {};

private _next = {
    private _r = "archangel" callExtension ["ramet.bulk.next_world", ["ingame"]];
    _r param [0, "", [""]]
};

private _markDone = {
    params ["_world", "_ok", ["_err", ""]];
    "archangel" callExtension ["ramet.bulk.mark_done", ["ingame", _world, str _ok, _err]];
};

private _log = {
    params ["_msg"];
    "archangel" callExtension ["ramet.bulk.log_progress", [_msg]];
    diag_log text format ["[RAMET ingame] %1", _msg];
};

if (isNil "a3me_export") exitWith {
    ["ERROR: a3me_export not defined — @arma3MapExporter not loaded"] call _log;
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
        [] spawn a3me_export;

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

private _summary = "archangel" callExtension ["ramet.bulk.export_summary", ["ingame"]];
[format ["bulk ingame export complete — %1", _summary]] call _log;
endMission "END1";
