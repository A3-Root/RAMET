/*
 * Author: Root
 * Description: onLoad handler for ramet_ingame_main dialog.
 *              Populates the tile grid from CfgWorldList using grad_meh's
 *              mapItem controls, restoring prior selection state.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 *
 * Public: No
 */

params ["_display"];

private _mapList = _display displayCtrl 742123;

private _worlds = "true" configClasses (configFile >> "CfgWorldList");
private _selectedMaps = uiNamespace getVariable ["ramet_ingame_selectedMaps", []];

private _gridW = pixelW * pixelGrid;
private _gridH = pixelH * pixelGrid;
private _mapItemW = 30;
private _mapItemH = 40;
private _spacing = 1;

private _listW = ((ctrlPosition _mapList) select 2) / _gridW;
private _columns = floor (_listW / _mapItemW);
_columns = (_columns max 1) min (count _worlds);

private _sidePadding = (_listW - _columns * _mapItemW) / 2;

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
    ] call (uiNamespace getVariable "grad_meh_fnc_mapItem_create");

    private _row = floor (_forEachIndex / _columns);
    private _col = _forEachIndex % _columns;
    _item ctrlSetPosition [
        (_sidePadding + _col * _mapItemW) * _gridW,
        (_row * _mapItemH + _spacing) * _gridH
    ];
    _item ctrlCommit 0;
} forEach _worlds;
