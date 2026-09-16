#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

private _exportSat = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_SAT);
private _exportTopo = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_TOPO);
private _exportBakedTopo = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_BAKEDTOPO);
private _exportHouses = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_HOUSES);
private _exportPreviewImg = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_PREVIEW);
private _exportMeta = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_META);
private _exportDem = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_DEM);

private _sourceOptions = [_exportSat, _exportTopo, _exportBakedTopo, _exportHouses, _exportPreviewImg, _exportMeta, _exportDem];

uiNamespace setVariable ["ocap_renderterrain_options", _sourceOptions];

// RAMET's multi-mode export borrows this dialog to collect OCAP's options; it
// stores them and moves to the next mode instead of exporting now.
private _collecting = uiNamespace getVariable ["ramet_all_collecting", false];

if (_collecting) exitWith {
	if (_exitCode isNotEqualTo 1) exitWith {
		[] call (uiNamespace getVariable "root_amet_fnc_allAbort");
		diag_log "[RAMET all] OCAP options cancelled — returning to the main menu.";
	};
	if (_sourceOptions findIf {_x} isEqualTo -1) exitWith {
		(displayParent _display) spawn { _this createDisplay "ocap_renderterrain_config"; };
	};
	uiNamespace setVariable ["ramet_all_opt_ocap", _sourceOptions];
	[] call (uiNamespace getVariable "root_amet_fnc_allNextOptions");
};

if (_exitCode isEqualTo 1) then {
	// user pressed ok

	// check if any option is selected
	if (_sourceOptions findIf {_x} isEqualTo -1) then {
		(displayParent _display) spawn { _this createDisplay "ocap_renderterrain_config"; };
	} else {
		// start export
		[
			(uiNamespace getVariable ["ocap_renderterrain_selectedMaps", []]),
			_exportSat,
			_exportTopo,
			_exportBakedTopo,
			_exportHouses,
			_exportPreviewImg,
			_exportMeta,
			_exportDem
		] call (uiNamespace getVariable "ocap_renderterrain_fnc_export");
	};

} else {
	// user pressed cancel -> open main display
	(displayParent _display) spawn { _this createDisplay "ocap_renderterrain_main"; };
};

