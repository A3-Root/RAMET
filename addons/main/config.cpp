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

#include "script_images.hpp"

class ctrlControlsGroupNoScrollbars;
class ctrlControlsGroupNoHScrollbars;
class ctrlStatic;
class ctrlStaticBackground;
class ctrlStaticTitle;
class ctrlStaticFooter;
class ctrlStaticPictureKeepAspect;
class ctrlButton;
class ctrlButtonOK;
class ctrlButtonCancel;

#include "controls\mapItem.hpp"
#include "dialogs\ingame_main.hpp"

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
        };
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
        picture = RAMET_IMG_SPOTLIGHT_GRAD_MEH;
        video = "";
        action = "params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'grad_meh_main';";
        actionText = "OPEN";
        condition = "true";
    };
    class ramet_ocap {
        text = "RAMET — OCAP export (diag)";
        textIsQuote = 0;
        picture = RAMET_IMG_SPOTLIGHT_OCAP;
        video = "";
        action = "params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'ocap_renderterrain_main';";
        actionText = "OPEN";
        condition = "true";
    };
    class ramet_ingame {
        text = "RAMET — In-Game export (GMS)";
        textIsQuote = 0;
        picture = RAMET_IMG_SPOTLIGHT_INGAME;
        video = "";
        action = "params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'ramet_ingame_main';";
        actionText = "OPEN";
        condition = "true";
    };
};
