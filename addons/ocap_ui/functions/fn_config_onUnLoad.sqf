#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

private _exportSat = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_SAT);
private _exportTopo = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_TOPO);
private _exportBakedTopo = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_BAKEDTOPO);
private _exportHouses = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_HOUSES);
private _exportPreviewImg = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_PREVIEW);
private _exportMeta = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_META);
private _exportDem = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_DEM);
private _processDockerInGame = cbChecked (_display displayCtrl IDC_CONFIG_CHECK_DOCKER);

private _sourceOptions = [_exportSat, _exportTopo, _exportBakedTopo, _exportHouses, _exportPreviewImg, _exportMeta, _exportDem];
private _options = _sourceOptions + [_processDockerInGame];

uiNamespace setVariable ["ocap_renderterrain_options", _options];

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
			_exportDem,
			_processDockerInGame
		] call (uiNamespace getVariable "ocap_renderterrain_fnc_export");
	};

} else {
	// user pressed cancel -> open main display
	(displayParent _display) spawn { _this createDisplay "ocap_renderterrain_main"; };
};

