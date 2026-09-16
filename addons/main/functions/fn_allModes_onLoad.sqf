/*
 * Author: Root
 * Description: onLoad handler for the ramet_all_modes dialog.
 *              Restores the previous tick marks and greys out the modes the
 *              current Arma binary cannot run.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display"];

private _selected = uiNamespace getVariable ["ramet_all_modes", ["grad_meh", "ocap", "ingame"]];
// The diagnostics binary has no Grad_meh and no GMS exporter, which is why
// their spotlight tiles are hidden there too.
private _isDiag = uiNamespace getVariable ["ramet_isDiagBuild", false];

private _setRow = {
	params ["_display", "_idc", "_on", "_enabled"];
	private _ctrl = _display displayCtrl _idc;
	if (isNull _ctrl) exitWith {};
	_ctrl cbSetChecked (_on && _enabled);
	_ctrl ctrlEnable _enabled;
	_ctrl ctrlCommit 0;
};

[_display, IDC_ALL_CHECK_GRAD, "grad_meh" in _selected, !_isDiag] call _setRow;
[_display, IDC_ALL_CHECK_OCAP, "ocap" in _selected, true] call _setRow;
[_display, IDC_ALL_CHECK_GMS, "ingame" in _selected, !_isDiag] call _setRow;
