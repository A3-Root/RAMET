#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

private _exportSat = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_SAT);
private _exportTopo = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_TOPO);
private _exportBakedTopo = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_BAKEDTOPO);
private _exportHouses = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_HOUSES);
private _exportPreviewImg = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_PREVIEW);
private _exportMeta = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_META);
private _exportDem = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_DEM);

private _options = [_exportSat, _exportTopo, _exportBakedTopo, _exportHouses, _exportPreviewImg, _exportMeta, _exportDem];

uiNamespace setVariable ["grad_meh_options", _options];

// RAMET's multi-mode export borrows this dialog to collect Grad_meh's options;
// it stores them and moves to the next mode instead of exporting now.
private _collecting = uiNamespace getVariable ["ramet_all_collecting", false];

if (_collecting) exitWith {
	if (_exitCode isNotEqualTo 1) exitWith {
		[] call (uiNamespace getVariable "root_amet_fnc_allAbort");
		diag_log "[RAMET all] Grad_meh options cancelled — returning to the main menu.";
	};
	if (_options findIf {_x} isEqualTo -1) exitWith {
		(displayParent _display) spawn { _this createDisplay "grad_meh_config"; };
	};
	uiNamespace setVariable ["ramet_all_opt_grad_meh", _options];
	[] call (uiNamespace getVariable "root_amet_fnc_allNextOptions");
};

if (_exitCode isEqualTo 1) then {
	// user pressed ok

	// check if any option is selected
	if (_options findIf {_x} isEqualTo -1) then {
		(displayParent _display) spawn { _this createDisplay "grad_meh_config"; };
	} else {
		// start export
		[
			(uiNamespace getVariable ["grad_meh_selectedMaps", []]),
			_exportSat,
			_exportTopo,
			_exportBakedTopo,
			_exportHouses,
			_exportPreviewImg,
			_exportMeta,
			_exportDem
		] call (uiNamespace getVariable "grad_meh_fnc_export");
	};

} else {
	// user pressed cancel -> open main display
	(displayParent _display) spawn { _this createDisplay "grad_meh_main"; };
};

