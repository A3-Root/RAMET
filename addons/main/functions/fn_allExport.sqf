/*
 * Author: Root
 * Description: Run the chosen export modes over the selected worlds, unattended.
 *
 * Each mode already exports a whole list of worlds on its own and returns to
 * the main menu when the list is finished. This function only queues the modes
 * and remembers where it is; RAMET's RscDisplayMain hook calls
 * root_amet_fnc_allResume every time the main menu comes back, which is what
 * advances the queue to the next mode.
 *
 * State lives in uiNamespace because it has to survive the mission loads each
 * mode performs:
 *   ramet_all_worlds      selected world class names <ARRAY>
 *   ramet_all_modes       modes to run, in order <ARRAY>
 *   ramet_all_opt_<mode>  that mode's options <ARRAY>
 *   ramet_all_stageIndex  index into ramet_all_modes <NUMBER>
 *   ramet_all_running     true while a mode is exporting <BOOL>
 *   ramet_all_active      true from the first mode until the last finishes <BOOL>
 *
 * Arguments:
 * 0: World class names <ARRAY>
 *
 * Public: No
 */
#include "..\script_component.hpp"

params [["_maps", [], [[]]]];

private _modes = uiNamespace getVariable ["ramet_all_modes", []];

if (_maps isEqualTo [] || {_modes isEqualTo []}) exitWith {
	[] call (uiNamespace getVariable "root_amet_fnc_allAbort");
	diag_log format ["[RAMET all] Nothing to export (worlds=%1 modes=%2).", _maps, _modes];
};

uiNamespace setVariable ["ramet_all_worlds", +_maps];
uiNamespace setVariable ["ramet_all_stageIndex", 0];
uiNamespace setVariable ["ramet_all_running", false];
uiNamespace setVariable ["ramet_all_active", true];

diag_log format ["[RAMET all] Queue starting — worlds=%1 modes=%2", _maps, _modes];

[] call (uiNamespace getVariable "root_amet_fnc_allStartStage");
