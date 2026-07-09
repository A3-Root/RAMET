/*
 * Author: Root
 * Description: Bulk-export every world in worlds.txt via grad_meh.
 *              FlatDevil drives the loop: ramet.bulk.next_world() / mark_done() / log_progress().
 *              ramet.stage.move_grad_meh() shifts finished output into RAMET/output/_intermediate/.
 *
 * Public: No
 *
 * Usage:
 *   Loaded from mission init.sqf:
 *     [] spawn ramet_fnc_bulkExportGradMeh;
 */

#include "..\script_component.hpp"

if (!isServer) exitWith {};

private _next = {
    private _r = ["ramet.bulk.next_world", ["grad_meh"]] call ramet_fnc_fdCall;
    _r params ["_ok", ["_value", []]];
    if (!_ok) exitWith {
        // bridge failure ends the queue: an empty world name stops the loop
        diag_log text format ["[RAMET grad_meh] ERROR next_world: %1", _r];
        ""
    };
    _value param [0, "", [""]]
};

private _markDone = {
    params ["_world", "_ok", ["_err", ""]];
    private _r = ["ramet.bulk.mark_done", ["grad_meh", _world, _ok, _err]] call ramet_fnc_fdCall;
    if !(_r select 0) then {
        diag_log text format ["[RAMET grad_meh] ERROR mark_done %1: %2", _world, _r];
    };
};

private _log = {
    params ["_msg"];
    ["ramet.bulk.log_progress", [_msg]] call ramet_fnc_fdCall;
    diag_log text format ["[RAMET grad_meh] %1", _msg];
};

[format ["bulk grad_meh export starting (worldName=%1)", worldName]] call _log;

while {true} do {
    private _world = call _next;
    if (_world == "") exitWith { ["world list exhausted"] call _log; };
    if (toLower _world != toLower worldName) then {
        [format ["WARN: queued world '%1' but running world is '%2' — skipping", _world, worldName]] call _log;
        [_world, false, "world mismatch — relaunch Arma with this world"] call _markDone;
    } else {
        [format ["exporting %1", _world]] call _log;

        // gradMehExportMap [mapId, sat, topo, bakedTopo, geojson, previewImg, meta, dem]
        private _args = [_world, true, true, true, true, true, true, true];
        call compile ("gradMehExportMap (" + str _args + ")");

        // poll until done
        waitUntil {
            sleep 2;
            if (isNil { call compile "gradMehExportRunning" }) exitWith { true };
            !(call compile "gradMehExportRunning")
        };

        // gradMehExportFailed = true when grad_meh caught an error without rethrowing
        private _exportOk = !(call compile "gradMehExportFailed");

        if (_exportOk) then {
            [_world, true, ""] call _markDone;
            [format ["finished %1", _world]] call _log;
        } else {
            [format ["WARN: grad_meh failed to export '%1' — unsupported map, skipping", _world]] call _log;
            [_world, false, "grad_meh export failed — unsupported map"] call _markDone;
        };
    };
};

private _r = ["ramet.bulk.export_summary", ["grad_meh"]] call ramet_fnc_fdCall;
_r params ["_ok", ["_summary", []]];
if (!_ok) then {
    diag_log text format ["[RAMET grad_meh] ERROR export_summary: %1", _r];
};
_summary params [["_total", 0, [0]], ["_skipped", 0, [0]], ["_names", "", [""]]];

private _summaryMsg = format ["bulk grad_meh export complete — %1 processed, %2 skipped", _total, _skipped];
[_summaryMsg] call _log;

if (_skipped > 0) then {
    [format ["skipped maps: %1", _names]] call _log;
};

endMission "END1";
