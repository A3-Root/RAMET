#include "loadingStep.hpp"

#define NAME_HEIGHT 5
#define BOTTOM_MARGIN 2.5
#define STEP_Y(index) ((NAME_HEIGHT + index * LOADING_STEP_H) * GRID_H)

class ocap_renderterrain_loadingItem: ctrlControlsGroupNoScrollbars {
	x = QUOTE(SPACING * GRID_W);
	y = QUOTE(SPACING * GRID_H);
	w = LOADING_STEP_W;
	h = QUOTE(STEP_Y(3) + BOTTOM_MARGIN * GRID_H);
	class Controls {
		class name: ctrlStatic {
			idc = IDC_LOADINGITEM_NAME;
			x = 0;
			y = 0;
			w = LOADING_STEP_W;
			h = QUOTE(NAME_HEIGHT * GRID_H);
			sizeEx = QUOTE(NAME_HEIGHT * GRID_H);
		};
		class readWrp: ocap_renderterrain_loadingStep {
			idc = IDC_LOADINGITEM_STEP_READWRP;
			y = QUOTE(STEP_Y(0));
			class Controls: Controls {
				class done: done {};
				class text: text {
					text = "Load terrain";
				};
			};
		};
		class satImage: ocap_renderterrain_loadingStep {
			idc = IDC_LOADINGITEM_STEP_SATIMAGE;
			y = QUOTE(STEP_Y(1));
			class Controls: Controls {
				class done: done {};
				class text: text {
					text = "Export SVG and heightmap";
				};
			};
		};
		class topoImage: ocap_renderterrain_loadingStep {
			idc = IDC_LOADINGITEM_STEP_TOPOIMAGE;
			y = QUOTE(STEP_Y(2));
			class Controls: Controls {
				class done: done {};
				class text: text {
					text = "Run Docker render";
				};
			};
		};
	};
};

class ocap_renderterrain_loadingItem_error: ocap_renderterrain_loadingItem {
	h = QUOTE(STEP_Y(1) + BOTTOM_MARGIN * GRID_H);
	class Controls {
		class name: ctrlStatic {
			idc = IDC_LOADINGITEM_NAME;
			x = 0;
			y = 0;
			w = LOADING_STEP_W;
			h = QUOTE(NAME_HEIGHT * GRID_H);
			sizeEx = QUOTE(NAME_HEIGHT * GRID_H);
		};
		class error: name {
			idc = IDC_LOADINGITEM_ERROR;
			y = QUOTE(STEP_Y(0));
			h = QUOTE(LOADING_STEP_H * GRID_H);
			sizeEx = QUOTE(LOADING_STEP_H * 0.9 * GRID_H);
		};
	};
};

#undef NAME_HEIGHT
#undef BOTTOM_MARGIN
#undef STEP_Y
