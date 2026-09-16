#include "../idcmacros.hpp"

params ["_display", "_exitCode"];

// RAMET's multi-mode export hands over to the next mode here, while this
// mission is still running. It has to happen now and synchronously: once the
// mission ends there is no scheduler left in the main menu to resume a
// spawned script.
private _chained = false;
if (uiNamespace getVariable ["ramet_all_active", false]) then {
	_chained = [] call (uiNamespace getVariable "root_amet_fnc_allChainNext");
};

// The next mode loads its own mission and ends this one itself.
if (_chained) exitWith {};

// exit mission
[] spawn {
	sleep 0.5;
	endMission "END1";
};
