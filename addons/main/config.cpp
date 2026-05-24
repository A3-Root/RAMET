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
