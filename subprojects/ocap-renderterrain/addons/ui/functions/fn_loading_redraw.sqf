/*
 * Author: DerZade
 * Redraw the loading screen
 *
 * Arguments:
 * 0: Loading display <DISPLAY>
 *
 * Return Value:
 * NONE
 *
 * Example:
 * [(uiNamespace getVariable "ocap_renderterrain_loadingDisplay")] call ocap_renderterrain_fnc_loading_redraw;
 *
 * Public: No
 */

#include "../idcmacros.hpp"

params ["_display"];

private _worlds = _display getVariable ["ocap_renderterrain_worlds", []];
private _loadingList = _display displayCtrl IDC_DIALOG_CONTENT;

// clear loadingList 
{
	if (ctrlClassName _x isEqualTo "ocap_renderterrain_loadingItem") then {
		ctrlDelete _x;
	};
} forEach (allControls _display);


private _allDone = true;
private _yPos = (SPACING * GRID_H);
{
	private _return = [
		_display,
		_loadingList,
		_x
	] call (uiNamespace getVariable "ocap_renderterrain_fnc_loadingItem_create");

	_return params ["_item", "_done"];
	_allDone = _allDone && _done;

	_item ctrlSetPositionY _yPos;
	_item ctrlCommit 0;

	private _height = (ctrlPosition _item) select 3;
	_yPos = _yPos + _height;
} forEach _worlds;

if (_allDone) then {
	[_display, _worlds] spawn {
		params ["_display", "_worlds"];

		private _parent = displayParent _display;
		_display closeDisplay 1;
		private _doneDisp = _parent createDisplay "ocap_renderterrain_done";
		_doneDisp setVariable ["ocap_renderterrain_worlds", _worlds];
		[_doneDisp] call (uiNamespace getVariable 'ocap_renderterrain_fnc_done_onLoad');
	};
};
