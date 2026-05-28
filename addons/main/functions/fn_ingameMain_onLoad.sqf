/*
 * Author: Root (adapted from DerZade / grad_meh)
 * onLoad handler for ramet_ingame_main dialog.
 * Populates the tile grid from CfgWorldList, restoring prior selection state.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display"];

private _mapList = _display displayCtrl IDC_DIALOG_CONTENT;

private _worlds = ("true" configClasses (configFile >> "CfgWorldList"));
private _selectedMaps = uiNamespace getVariable ["ramet_ingame_selectedMaps", []];

private _listW = ((ctrlPosition _mapList) select 2) / GRID_W;
private _columns = floor (_listW / MAP_ITEM_W);
_columns = _columns min (count _worlds);

private _sidePadding = (_listW - _columns * MAP_ITEM_W) / 2;

{
	private _worldName = configName _x;
	private _config = (configFile >> "CfgWorlds" >> _worldName);
	private _displayName = [_config, "description", ""] call (uiNamespace getVariable "BIS_fnc_returnConfigEntry");
	private _image = [_config, "pictureMap", ""] call (uiNamespace getVariable "BIS_fnc_returnConfigEntry");
	private _author = [_config, "author", ""] call (uiNamespace getVariable "BIS_fnc_returnConfigEntry");
	private _selected = _worldName in _selectedMaps;

	private _item = [
		_display,
		_mapList,
		_worldName,
		_image,
		_displayName,
		_author,
		_selected
	] call (uiNamespace getVariable "root_amet_fnc_ingameMapItem_create");

	private _row = floor (_forEachIndex / _columns);
	private _col = _forEachIndex % _columns;
	_item ctrlSetPosition [
		(_sidePadding + _col * MAP_ITEM_W) * GRID_W,
		(_row * MAP_ITEM_H + SPACING) * GRID_H
	];
	_item ctrlCommit 0;
} forEach _worlds;
