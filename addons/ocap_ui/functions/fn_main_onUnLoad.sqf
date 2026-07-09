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
	// user pressed cancel
	[displayParent _display] spawn {
		params ["_parent"];

		if (isNil "BIS_fnc_guiMessage") exitWith {
			_parent createDisplay "ocap_renderterrain_main";
		};

		private _result = [
			"Are you sure you want to quit OCAP RenderTerrain?", 
			"Quit OCAP RenderTerrain",
			true,
			true,
			_parent
		] call (uiNamespace getVariable "BIS_fnc_guiMessage");

		if (_result) exitWith {};

		// create loading display
		_parent createDisplay "ocap_renderterrain_main";
	};
};
