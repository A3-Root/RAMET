#include "../idcmacros.hpp"

#define ROW_HEIGHT 3
#define ROW_Y(index) ((SPACING + index * ROW_HEIGHT) * GRID_H)
#define DIALOG_WIDTH (60 * GRID_W)
#define DIALOG_HEIGHT (ROW_Y(3) + SPACING * GRID_H)
#define DIALOG_TITLE "RAMET - Choose export modes"
#define DIALOG_NON_SCROLLABLE true

// First step of the multi-mode export: tick the exporters to run. The map
// picker and each mode's own options follow, then everything runs unattended.
// Rows are in run order — GMS last, because it is the screenshot-driven one.
class ramet_all_modes {
	idd = -1;
	movingEnable = 0;
	onLoad = "call (uiNamespace getVariable 'root_amet_fnc_allModes_onLoad');";
	onUnLoad = "call (uiNamespace getVariable 'root_amet_fnc_allModes_onUnLoad');";
	#include "base\start.hpp"
	class grad: ctrlControlsGroupNoScrollbars {
		x = QUOTE(SPACING * GRID_W);
		y = QUOTE(ROW_Y(0));
		w = QUOTE(DIALOG_WIDTH);
		h = QUOTE(ROW_HEIGHT * GRID_H);
		idc = -1;
		class Controls {
			class check: ctrlCheckbox {
				idc = IDC_ALL_CHECK_GRAD;
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
				text = "Grad_meh export (satellite, vectors, DEM, 3D)";
				sizeEx = QUOTE(ROW_HEIGHT * 0.9 * GRID_H);
			};
		};
	};
	class ocap: grad {
		y = QUOTE(ROW_Y(1));
		class Controls: Controls {
			class check: check {
				idc = IDC_ALL_CHECK_OCAP;
			};
			class text: text {
				text = "OCAP RenderTerrain export (high-resolution topo source)";
			};
		};
	};
	// Listed last because it runs last: see fn_allModes_onUnLoad.
	class gms: grad {
		y = QUOTE(ROW_Y(2));
		class Controls: Controls {
			class check: check {
				idc = IDC_ALL_CHECK_GMS;
			};
			class text: text {
				text = "In-Game export (GMS aerial and topographic imagery)";
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
