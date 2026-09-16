/*
 * Author: Root
 * Description: Walk the selected exporters' options dialogs, one after another,
 *              then start the run.
 *
 * Grad_meh and OCAP reuse their own existing options dialogs, which check
 * ramet_all_collecting in their onUnLoad and hand control back here instead of
 * exporting straight away. GMS gets ramet_all_gms_config. Once every selected
 * mode has been asked, the whole run starts and needs no further input.
 *
 * Public: No
 */
#include "..\script_component.hpp"

private _modes = uiNamespace getVariable ["ramet_all_modes", []];
private _index = uiNamespace getVariable ["ramet_all_optIndex", 0];

if (_index >= count _modes) exitWith {
	uiNamespace setVariable ["ramet_all_collecting", false];
	diag_log "[RAMET all] Options collected — starting the run.";
	[uiNamespace getVariable ["ramet_all_worlds", []]] call (uiNamespace getVariable "root_amet_fnc_allExport");
};

private _mode = _modes select _index;
uiNamespace setVariable ["ramet_all_optIndex", _index + 1];
uiNamespace setVariable ["ramet_all_collecting", true];

private _display = switch (_mode) do {
	case "grad_meh": { "grad_meh_config" };
	case "ingame": { "ramet_all_gms_config" };
	case "ocap": { "ocap_renderterrain_config" };
	default { "" };
};

if (_display isEqualTo "") exitWith {
	diag_log format ["[RAMET all] No options dialog for '%1' — skipping.", _mode];
	[] call (uiNamespace getVariable "root_amet_fnc_allNextOptions");
};

// Seed the mode's own options variable so its dialog opens on the previous
// choice rather than on whatever a standalone export left behind.
switch (_mode) do {
	case "grad_meh": {
		uiNamespace setVariable ["grad_meh_options",
			uiNamespace getVariable ["ramet_all_opt_grad_meh", [true, true, true, true, true, true, true]]];
	};
	case "ocap": {
		uiNamespace setVariable ["ocap_renderterrain_options",
			uiNamespace getVariable ["ramet_all_opt_ocap", [true, true, true, true, true, true, true]]];
	};
};

diag_log format ["[RAMET all] Asking for %1 options (%2).", _mode, _display];

[_display] spawn {
	params ["_class"];
	// findDisplay 0 is the main menu, which is the parent every RAMET dialog
	// in this chain is created under.
	(findDisplay 0) createDisplay _class;
};
