/*
 * Author: Root
 * Description: onUnLoad handler for the ramet_all_gms_config dialog.
 *              Stores the optional GMS passes and moves to the next mode's
 *              options. Cancel drops the whole multi-mode run.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 * 1: Exit code (1 = OK, 0 = Cancel) <NUMBER>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

if (_exitCode isNotEqualTo 1) exitWith {
	[] call (uiNamespace getVariable "root_amet_fnc_allAbort");
	diag_log "[RAMET all] In-game options cancelled — returning to the main menu.";
};

// Both unticked is valid: that exports the topographic pass alone.
private _options = [
	cbChecked (_display displayCtrl IDC_ALL_CHECK_GMS_HIRES),
	cbChecked (_display displayCtrl IDC_ALL_CHECK_GMS_AERIAL)
];

uiNamespace setVariable ["ramet_all_opt_ingame", _options];

[] call (uiNamespace getVariable "root_amet_fnc_allNextOptions");
