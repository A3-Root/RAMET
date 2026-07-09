#include "script_component.hpp"

class CfgPatches {
	class ocap_renderterrain_ui {
		name = "OCAP RenderTerrain - UI";
		units[] = {};
		weapons[] = {};
		requiredVersion = 1.92;
		requiredAddons[] = { "ocap_renderterrain_exporter" };
		authors[] = { "OCAP", "indig0fox" };
		url = "";
		version = 2.14;
	};
};

class ctrlControlsGroupNoScrollbars;
class ctrlStatic;
class ctrlStaticPictureKeepAspect;
class ctrlControlsGroupNoHScrollbars;
class ctrlButton;
class ctrlStructuredText;
class ctrlStaticBackground;
class ctrlStaticTitle;
class ctrlStaticFooter;
class ctrlButtonOK;
class ctrlButtonClose;
class ctrlButtonCancel;
class ctrlCheckbox;
class Attributes;

#include "idcmacros.hpp"

// controls
#include "controls\loadingItem.hpp"
#include "controls\mapItem.hpp"

// dialogs
#include "dialogs\main.hpp"
#include "dialogs\config.hpp"
#include "dialogs\loading.hpp"
#include "dialogs\done.hpp"

#include "CfgFunctions.hpp"

// RAMET (@root_amet) is the single main-menu entry point. The original
// auto-open RscDisplayMain hook and CfgMainMenuSpotlight tile were removed
// from this subproject — RAMET's picker calls
// `createDisplay "ocap_renderterrain_main"` when the operator chooses OCAP.
