/*
 * Author: Root (adapted from DerZade / grad_meh)
 * Triggered by onMouseButtonClick EH of any ramet_ingame_mapItem control.
 * Toggles the selected state of the map item.
 *
 * Arguments:
 * 0: The clicked control <CONTROL>
 *
 * Return Value:
 * None
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_control"];

private _grp = ctrlParentControlsGroup _control;
private _selected = _grp getVariable ["ramet_ingame_selected", false];
_grp setVariable ["ramet_ingame_selected", !_selected];
(_grp controlsGroupCtrl IDC_MAPITEM_SELECTINDICATOR) ctrlShow (!_selected);
