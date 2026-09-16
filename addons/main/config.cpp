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

class Extended_PreStart_EventHandlers {
    class ADDON {
        init = QUOTE(call compile preprocessFileLineNumbers '\z\root_amet\addons\main\XEH_preStart.sqf');
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

#include "script_images.hpp"

class ctrlControlsGroupNoScrollbars;
class ctrlControlsGroupNoHScrollbars;
class ctrlStatic;
class ctrlCheckbox;
class ctrlStaticBackground;
class ctrlStaticTitle;
class ctrlStaticFooter;
class ctrlStaticPictureKeepAspect;
class ctrlButton;
class ctrlButtonOK;
class ctrlButtonCancel;

#include "controls\mapItem.hpp"
#include "dialogs\ingame_main.hpp"
#include "dialogs\all_modes.hpp"
#include "dialogs\all_main.hpp"
#include "dialogs\all_gms_config.hpp"

class RscDisplayDebriefing {
    onLoad = "if (uiNamespace getVariable ['ramet_ingame_autoCloseDebriefing', false]) then { [_this select 0] call (uiNamespace getVariable 'ramet_ingame_fnc_closeDebriefing'); };";
};

class CfgFunctions {
    class root_amet {
        class ingame_ui {
            file = "\z\root_amet\addons\main\functions";
            class ingameMain_onLoad {};
            class ingameMain_onUnLoad {};
            class ingameMapItem_create {};
            class ingameMapItem_onClick {};
            class ingameExport {};
            class allExport {};
            class allStartStage {};
            class allChainNext {};
            class allAbort {};
            class allModes_onLoad {};
            class allModes_onUnLoad {};
            class allGmsConfig_onLoad {};
            class allGmsConfig_onUnLoad {};
            class allNextOptions {};
            class isDiagBuild {};
        };
    };
};

// Main-menu spotlight tiles — RAMET reuses the upstream mods' own dialogs.
// The single-mode tiles open the corresponding mod's existing UI directly; no
// custom dialog, no auto-popup, no script. Matches the pattern grad_meh and
// ocap-renderterrain themselves use (those tiles were stripped from the
// subprojects so RAMET is the only entry point). The multi-mode tile adds a
// mode picker in front of that same chain.
class CfgMainMenuSpotlight {
    class ramet_grad_meh {
        text = "RAMET — Grad_meh export";
        textIsQuote = 0;
        picture = RAMET_IMG_SPOTLIGHT_GRAD_MEH;
        video = "";
        action = "params ['_ctrl']; call (uiNamespace getVariable 'root_amet_fnc_allAbort'); (ctrlParent _ctrl) createDisplay 'grad_meh_main';";
        actionText = "OPEN";
        condition = "!(uiNamespace getVariable ['ramet_isDiagBuild', false])";
    };
    class ramet_ocap {
        text = "RAMET — OCAP export";
        textIsQuote = 0;
        picture = RAMET_IMG_SPOTLIGHT_OCAP;
        video = "";
        action = "params ['_ctrl']; call (uiNamespace getVariable 'root_amet_fnc_allAbort'); (ctrlParent _ctrl) createDisplay 'ocap_renderterrain_main';";
        actionText = "OPEN";
        condition = "true";
    };
    class ramet_all {
        text = "RAMET — Multi-mode export";
        textIsQuote = 0;
        picture = RAMET_IMG_SPOTLIGHT_ALL;
        video = "";
        action = "params ['_ctrl']; call (uiNamespace getVariable 'root_amet_fnc_allAbort'); (ctrlParent _ctrl) createDisplay 'ramet_all_modes';";
        actionText = "OPEN";
        condition = "true";
    };
    class ramet_ingame {
        text = "RAMET — In-Game export (GMS)";
        textIsQuote = 0;
        picture = RAMET_IMG_SPOTLIGHT_INGAME;
        video = "";
        action = "params ['_ctrl']; call (uiNamespace getVariable 'root_amet_fnc_allAbort'); (ctrlParent _ctrl) createDisplay 'ramet_ingame_main';";
        actionText = "OPEN";
        condition = "!(uiNamespace getVariable ['ramet_isDiagBuild', false])";
    };
};
