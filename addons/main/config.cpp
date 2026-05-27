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

// Two main-menu spotlight tiles — RAMET reuses the upstream mods' own dialogs.
// Each tile directly opens the corresponding mod's existing UI; no custom
// dialog, no auto-popup, no script. Matches the pattern grad_meh and
// ocap-renderterrain themselves use (those tiles were stripped from the
// subprojects so RAMET is the only entry point).
class CfgMainMenuSpotlight {
    class ramet_grad_meh {
        text = "RAMET — Grad_meh export";
        textIsQuote = 0;
        picture = "\x\grad_meh\addons\ui\data\spotlight_co.paa";
        video = "";
        action = "params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'grad_meh_main';";
        actionText = "OPEN";
        condition = "true";
    };
    class ramet_ocap {
        text = "RAMET — OCAP export (diag)";
        textIsQuote = 0;
        picture = "\x\ocap_renderterrain\addons\ui\data\spotlight_co.paa";
        video = "";
        action = "params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'ocap_renderterrain_main';";
        actionText = "OPEN";
        condition = "true";
    };
    class ramet_ingame {
        text = "RAMET — In-Game export (GMS)";
        textIsQuote = 0;
        picture = "\x\arma3MapExporter\addons\exporter\data\spotlight_co.paa";
        video = "";
        // No GMS-side dialog; spin the bulk loop directly. SQF will pause until terminal.
        action = "[] spawn ramet_fnc_bulkExportInGame;";
        actionText = "RUN";
        condition = "!isNil 'a3me_export'";
    };
};
