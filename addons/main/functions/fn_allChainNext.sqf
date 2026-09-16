/*
 * Author: Root
 * Description: Hand the multi-mode queue over to the next export mode.
 *
 * Called from inside the mission a mode has just finished, immediately before
 * that mission would end. This has to happen there — and synchronously —
 * because a spawned script does not survive the mission ending, which is why
 * chaining from the main menu did not work.
 *
 * Returns true when it started another mode (whose own export function loads
 * the next mission, so the caller must not end the mission itself), false when
 * the queue is finished or inactive.
 *
 * Return Value:
 * Another mode was started <BOOL>
 *
 * Public: No
 */
#include "..\script_component.hpp"

if !(uiNamespace getVariable ["ramet_all_active", false]) exitWith { false };

private _modes = uiNamespace getVariable ["ramet_all_modes", []];
private _index = (uiNamespace getVariable ["ramet_all_stageIndex", 0]) + 1;

uiNamespace setVariable ["ramet_all_stageIndex", _index];
uiNamespace setVariable ["ramet_all_running", false];

if (_index >= count _modes) exitWith {
	private _worlds = uiNamespace getVariable ["ramet_all_worlds", []];
	uiNamespace setVariable ["ramet_all_active", false];
	uiNamespace setVariable ["ramet_all_stageIndex", 0];
	diag_log format ["[RAMET all] All export modes finished for %1. Run 03_postprocess next.", _worlds];
	false
};

diag_log format ["[RAMET all] Chaining to mode %1 of %2.", _index + 1, count _modes];
[] call (uiNamespace getVariable "root_amet_fnc_allStartStage");

// True only when a mode really started. A mode that cannot start falls through
// to the next one, and running ends up false once the queue is exhausted, so
// the caller knows it still has to end its own mission.
uiNamespace getVariable ["ramet_all_running", false]
