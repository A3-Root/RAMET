/*
 * Author: Root
 * Description: Bulk-export every world in worlds.txt via grad_meh.
 *              Archangel drives the loop: ramet.bulk.next_world() / mark_done() / log_progress().
 *              ramet.stage.move_grad_meh() shifts finished output into RAMET/output/_intermediate/.
 *
 * Public: No
 *
 * Usage:
 *   Loaded from mission init.sqf:
 *     [] spawn ramet_fnc_bulkExportGradMeh;
 */

#include "script_component.hpp"

if (!isServer) exitWith {};

private _next = {
    private _r = "archangel" callExtension ["ramet.bulk.next_world", []];
    _r param [0, "", [""]]
};

private _markDone = {
    params ["_world", "_ok", ["_err", ""]];
    "archangel" callExtension ["ramet.bulk.mark_done", [_world, str _ok, _err]];
};

private _log = {
    params ["_msg"];
    "archangel" callExtension ["ramet.bulk.log_progress", [_msg]];
    diag_log text format ["[RAMET grad_meh] %1", _msg];
};

private _stage = {
    params ["_world"];
    "archangel" callExtension ["ramet.stage.move_grad_meh", [_world]];
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
        private _status = call compile ("gradMehExportMap (" + str _args + ")");

        // poll until done
        waitUntil {
            sleep 2;
            if (isNil { call compile "gradMehExportRunning" }) exitWith { true };
            !(call compile "gradMehExportRunning")
        };

        [_world] call _stage;
        [_world, true, ""] call _markDone;
        [format ["finished %1", _world]] call _log;
    };
};

["bulk grad_meh export complete"] call _log;
endMission "END1";
