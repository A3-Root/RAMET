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

class RscStandardDisplay;
class RscDisplayMain: RscStandardDisplay
{
	class ControlsBackground 
	{
		class ocap_onLoadHandler: ctrlStatic {
			x = 0;
			y = 0;
			w = 0;
			h = 0;
			onLoad="params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'ocap_renderterrain_main';";
		};
	};
};

class CfgMainMenuSpotlight
{
	class ocap_renderterrain
	{
		text="OCAP RenderTerrain";
		textIsQuote=0;
		picture="\x\ocap_renderterrain\addons\ui\data\spotlight_co.paa";
		video="";
		action="params ['_ctrl']; (ctrlParent _ctrl) createDisplay 'ocap_renderterrain_main';";
		actionText="OPEN";
		condition="true";
	};
};
