#include "script_component.hpp"

if (!hasInterface) exitWith {};

ramet_exportRunning = false;

// CBA keybind: Ctrl+Shift+R opens the picker any time.
["RAMET", "openExportMenu", ["Open bulk export menu", "Show the grad_meh / OCAP picker."], {
    [] call ramet_fnc_showExportMenu;
}, {false}, [DIK_R, [false, true, true]]] call CBA_fnc_addKeybind;

// Auto-open the menu once after player init so the operator doesn't have to know the hotkey.
[] spawn {
    waitUntil { !isNull player && {!isNull (findDisplay 46)} };
    sleep 2;
    [] call ramet_fnc_showExportMenu;
};
