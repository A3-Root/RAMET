#include "../idcmacros.hpp"

#define DIALOG_WIDTH ((MAP_ITEM_W * 4 + 2 * SPACING) * GRID_W)
#define DIALOG_HEIGHT ((MAP_ITEM_H * 2 + 2 * SPACING) * GRID_H)
#define DIALOG_TITLE "RAMET - In-Game Export (GMS)"

class ramet_ingame_main {
	idd = -1;
	movingEnable = 0;
	onLoad = "call (uiNamespace getVariable 'root_amet_fnc_ingameMain_onLoad');";
	onUnLoad = "call (uiNamespace getVariable 'root_amet_fnc_ingameMain_onUnLoad');";
	#include "base\start.hpp"
	#include "base\end.hpp"
};

#undef DIALOG_WIDTH
#undef DIALOG_HEIGHT
#undef DIALOG_TITLE
