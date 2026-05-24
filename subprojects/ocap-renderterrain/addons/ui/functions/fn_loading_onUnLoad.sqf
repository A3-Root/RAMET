params ["_display", "_exitCode"];

if (_exitCode isNotEqualTo 2) exitWith {};

private _maps = _display getVariable ["ocap_renderterrain_worlds", []];

[displayParent _display, _maps] spawn {
	params ["_parent", "_maps"];

	if (isNil "BIS_fnc_guiMessage") exitWith {
		[] spawn {
			sleep 0.5;
			endMission "END1";
		};
	};

	private _result = [
		"Are you sure you want to quit OCAP RenderTerrain?<br/><br/><t size='0.7'>(We recommend restarting your game if you started any export process, to prevent any negative impacts on game performance.)</t>", 
		"Quit OCAP RenderTerrain",
		true,
		true,
		_parent
	] call (uiNamespace getVariable "BIS_fnc_guiMessage");

	if (_result) exitWith {
		// exit mission
		[] spawn {
			sleep 0.5;
			endMission "END1";
		};
	};

	// create loading display
	private _loadingDisplay = _parent createDisplay "ocap_renderterrain_loading";
	_loadingDisplay setVariable ["ocap_renderterrain_worlds", _maps];
	[_loadingDisplay] call (uiNamespace getVariable "ocap_renderterrain_fnc_loading_redraw");
};
