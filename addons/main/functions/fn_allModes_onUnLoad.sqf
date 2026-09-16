/*
 * Author: Root
 * Description: onUnLoad handler for the ramet_all_modes dialog.
 *              Stores the chosen exporters and moves on to the map picker.
 *              Re-opens itself if nothing was ticked; Cancel drops the whole
 *              multi-mode run and returns to the main menu.
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
	diag_log "[RAMET all] Mode selection cancelled — returning to the main menu.";
};

// Run order is fixed, not tick order: Grad_meh and OCAP read map data and are
// safe to leave alone, while GMS drives the camera and stitches screenshots, so
// it goes last — an unattended run gets the reliable exports done first.
private _modes = [];
if (cbChecked (_display displayCtrl IDC_ALL_CHECK_GRAD)) then { _modes pushBack "grad_meh" };
if (cbChecked (_display displayCtrl IDC_ALL_CHECK_OCAP)) then { _modes pushBack "ocap" };
if (cbChecked (_display displayCtrl IDC_ALL_CHECK_GMS)) then { _modes pushBack "ingame" };

uiNamespace setVariable ["ramet_all_modes", _modes];
diag_log format ["[RAMET all] Modes chosen: %1", _modes];

if (_modes isEqualTo []) exitWith {
	(displayParent _display) spawn { _this createDisplay "ramet_all_modes"; };
};

(displayParent _display) spawn { _this createDisplay "ramet_all_main"; };
