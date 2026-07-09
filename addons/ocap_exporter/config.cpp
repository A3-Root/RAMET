#include "script_version.hpp"

class CfgPatches {
	class ocap_renderterrain_exporter {
		name = "OCAP RenderTerrain Exporter";
		units[] = {};
		weapons[] = {};
		requiredVersion = 2.16;
		requiredAddons[] = { "A3_Functions_F", "cba_main" };
		authors[] = { "OCAP", "indig0fox" };
		url = "https://github.com/indig0fox/ocap-renderterrain";
		VERSION_CONFIG;
	};
};

#include "CfgFunctions.hpp"
