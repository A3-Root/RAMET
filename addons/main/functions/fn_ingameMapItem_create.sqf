/*
 * Author: Root (adapted from DerZade / grad_meh)
 * Create map item control for the ramet_ingame_main dialog.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 * 1: Existing controls group to create item in <CONTROL>
 * 2: worldName <STRING>
 * 3: Path to picture of map <STRING>
 * 4: Displayname <STRING>
 * 5: Author <STRING>
 * 6: Selected <BOOLEAN>
 *
 * Return Value:
 * Created control group <CONTROL>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display", "_parentGrp", "_worldName", "_image", "_displayName", "_author", "_selected"];

private _grp = _display ctrlCreate ["ramet_ingame_mapItem", -1, _parentGrp];
(_grp controlsGroupCtrl IDC_MAPITEM_PICTURE) ctrlSetText _image;
(_grp controlsGroupCtrl IDC_MAPITEM_NAME) ctrlSetText _displayName;
(_grp controlsGroupCtrl IDC_MAPITEM_AUTHOR) ctrlSetText format [" - %1", _author];
_grp setVariable ["ramet_ingame_worldName", _worldName];

if (_selected) then { (_grp controlsGroupCtrl IDC_MAPITEM_NAME) call (uiNamespace getVariable "root_amet_fnc_ingameMapItem_onClick"); };

_grp;
