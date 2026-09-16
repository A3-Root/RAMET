// Centralised image paths for all RAMET-managed UI assets.
// All PAA files live in addons\main\data\ — update here when any image changes.
// Every asset is 1024x1024 DXT1: the engine only loads power-of-two textures and
// rejects anything else with "Bad texture format.", leaving the control blank.

// Spotlight tile images
#define RAMET_IMG_SPOTLIGHT_GRAD_MEH    QUOTE(\z\root_amet\addons\main\data\spotlight_grad_meh_co.paa)
#define RAMET_IMG_SPOTLIGHT_OCAP        QUOTE(\z\root_amet\addons\main\data\spotlight_ocap_co.paa)
#define RAMET_IMG_SPOTLIGHT_INGAME      QUOTE(\z\root_amet\addons\main\data\spotlight_ingame_co.paa)
#define RAMET_IMG_SPOTLIGHT_ALL         QUOTE(\z\root_amet\addons\main\data\spotlight_all_co.paa)

// Mod logos (used in export-done screens)
#define RAMET_IMG_LOGO_GRAD_MEH         QUOTE(\z\root_amet\addons\main\data\logo_grad_meh_co.paa)
#define RAMET_IMG_LOGO_OCAP             QUOTE(\z\root_amet\addons\main\data\logo_ocap_co.paa)
#define RAMET_IMG_LOGO_INGAME           QUOTE(\z\root_amet\addons\main\data\logo_ingame_co.paa)
