#include "../idcmacros.hpp"

#define DIALOG_WIDTH ((MAP_ITEM_W * 4 + 2 * SPACING) * GRID_W)
#define DIALOG_HEIGHT ((MAP_ITEM_H * 2 + 2 * SPACING) * GRID_H)
#define DIALOG_TITLE "RAMET - Export All (Grad_meh + GMS + OCAP)"

// Same picker as the In-Game export, with the all-modes flag set on load so its
// onUnLoad starts the full queue instead of the GMS export alone.
class ramet_all_main {
	idd = -1;
	movingEnable = 0;
	onLoad = "uiNamespace setVariable ['ramet_all_pickerMode', true]; call (uiNamespace getVariable 'root_amet_fnc_ingameMain_onLoad');";
	onUnLoad = "call (uiNamespace getVariable 'root_amet_fnc_ingameMain_onUnLoad');";
	#include "base\start.hpp"
	#include "base\end.hpp"
};

#undef DIALOG_WIDTH
#undef DIALOG_HEIGHT
#undef DIALOG_TITLE
