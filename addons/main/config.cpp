#include "script_mod.hpp"

class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"cba_main"};
        author = "Root";
        authors[] = {"Root"};
        url = "https://github.com/A3-Root/RAMET";
        VERSION_CONFIG;
    };
};

class Extended_PreInit_EventHandlers {
    class ADDON {
        init = QUOTE(call compile preprocessFileLineNumbers '\z\root_amet\addons\main\XEH_preInit.sqf');
    };
};

class Extended_PostInit_EventHandlers {
    class ADDON {
        init = QUOTE(call compile preprocessFileLineNumbers '\z\root_amet\addons\main\XEH_postInit.sqf');
    };
};

// --- Main-menu picker. Overrides both grad_meh's and ocap-renderterrain's auto-open
//     and presents a single RAMET picker that delegates back to whichever mod the
//     operator chose. Handler name is prefixed `zzz_` so it sorts AFTER both
//     mods' ControlsBackground handlers and fires last (closes their dialog).
class ctrlStatic;
class RscStandardDisplay;
class RscDisplayMain: RscStandardDisplay {
    class ControlsBackground {
        class zzz_ramet_onLoadHandler: ctrlStatic {
            idc = -1;
            x = 0; y = 0; w = 0; h = 0;
            onLoad = "_this spawn (compile preprocessFileLineNumbers '\z\root_amet\addons\main\functions\fn_mainMenuPicker.sqf')";
        };
    };
};

class CfgMainMenuSpotlight {
    class ramet_bulk {
        text = "RAMET — Bulk Export";
        textIsQuote = 0;
        picture = "";
        video = "";
        action = "_this spawn (compile preprocessFileLineNumbers '\z\root_amet\addons\main\functions\fn_mainMenuPicker.sqf')";
        actionText = "OPEN";
        condition = "true";
    };
};
