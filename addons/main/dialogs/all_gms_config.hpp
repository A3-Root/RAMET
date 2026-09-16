#include "../idcmacros.hpp"

#define ROW_HEIGHT 3
#define ROW_Y(index) ((SPACING + index * ROW_HEIGHT) * GRID_H)
#define DIALOG_WIDTH (60 * GRID_W)
#define DIALOG_HEIGHT (ROW_Y(2) + SPACING * GRID_H)
#define DIALOG_TITLE "RAMET - In-Game (GMS) options"
#define DIALOG_NON_SCROLLABLE true

// Options for the In-Game exporter. Grad_meh and OCAP reuse their own existing
// options dialogs; GMS never had one, so this is it. The topographic pass is
// not listed: it also produces the calibration the other two passes need.
class ramet_all_gms_config {
	idd = -1;
	movingEnable = 0;
	onLoad = "call (uiNamespace getVariable 'root_amet_fnc_allGmsConfig_onLoad');";
	onUnLoad = "call (uiNamespace getVariable 'root_amet_fnc_allGmsConfig_onUnLoad');";
	#include "base\start.hpp"
	class hires: ctrlControlsGroupNoScrollbars {
		x = QUOTE(SPACING * GRID_W);
		y = QUOTE(ROW_Y(0));
		w = QUOTE(DIALOG_WIDTH);
		h = QUOTE(ROW_HEIGHT * GRID_H);
		idc = -1;
		class Controls {
			class check: ctrlCheckbox {
				idc = IDC_ALL_CHECK_GMS_HIRES;
				x = 0;
				y = QUOTE(ROW_HEIGHT * 0.05 * GRID_H);
				w = QUOTE(ROW_HEIGHT * 0.9 * GRID_W);
				h = QUOTE(ROW_HEIGHT * 0.9 * GRID_H);
				checked = 1;
			};
			class text: ctrlStatic {
				idc = -1;
				x = QUOTE(ROW_HEIGHT * GRID_W);
				y = 0;
				w = QUOTE(safezoneW - ROW_HEIGHT * GRID_W);
				h = QUOTE(ROW_HEIGHT * GRID_H);
				text = "High-resolution pass (terrains under 40960 m)";
				sizeEx = QUOTE(ROW_HEIGHT * 0.9 * GRID_H);
			};
		};
	};
	class aerial: hires {
		y = QUOTE(ROW_Y(1));
		class Controls: Controls {
			class check: check {
				idc = IDC_ALL_CHECK_GMS_AERIAL;
			};
			class text: text {
				text = "Aerial imagery pass (terrains under 40960 m)";
			};
		};
	};
	#include "base\end.hpp"
};

#undef ROW_HEIGHT
#undef ROW_Y
#undef DIALOG_WIDTH
#undef DIALOG_HEIGHT
#undef DIALOG_TITLE
#undef DIALOG_NON_SCROLLABLE
