params ["_display", "_exitCode"];

// get selected maps
private _maps = [];
{
	private _selected = _x getVariable ["ocap_renderterrain_selected", false];

	if (_selected) then {
		_maps pushBack (_x getVariable ["ocap_renderterrain_worldName", ""]);
	};
} forEach (allControls _display);

// save in ui namespace
uiNamespace setVariable ["ocap_renderterrain_selectedMaps", _maps];

if (_exitCode isEqualTo 1) then {
	// user pressed ok
	if (count _maps isEqualTo 0) then {
		(displayParent _display) spawn { _this createDisplay "ocap_renderterrain_main"; };
	} else {
		(displayParent _display) spawn { _this createDisplay "ocap_renderterrain_config"; };
	};
} else {
	// User pressed Cancel: let the display close and fall back to whatever
	// opened it (the main menu). Re-creating the picker here is what used to
	// make Cancel look like it did nothing.
	diag_log "[OCAP RenderTerrain] Map selection cancelled — returning to the main menu.";
};
