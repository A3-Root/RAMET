/*
 * Author: Root
 * Description: onLoad handler for ramet_ingame_main dialog.
 *              Populates the world list from CfgWorldList, restores prior selection.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 *
 * Public: No
 */

params ["_display"];

private _lb = _display displayCtrl 1010;
lbClear _lb;

private _worlds = "true" configClasses (configFile >> "CfgWorldList");
private _prevSelected = uiNamespace getVariable ["ramet_ingame_selectedMaps", []];

{
    private _className = configName _x;
    private _displayName = getText (configFile >> "CfgWorlds" >> _className >> "description");
    if (_displayName == "") then { _displayName = _className; };

    private _idx = _lb lbAdd format ["%1  (%2)", _displayName, _className];
    _lb lbSetData [_idx, _className];

    if (_className in _prevSelected) then {
        _lb lbSetSelected [_idx, true];
    };
} forEach _worlds;
