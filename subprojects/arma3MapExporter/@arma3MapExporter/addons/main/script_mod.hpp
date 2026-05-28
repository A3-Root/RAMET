#define MAINPREFIX z
#define PREFIX a3me

#include "script_version.hpp"

#define VERSION MAJOR.MINOR.PATCH.BUILD
#define VERSION_AR MAJOR,MINOR,PATCH,BUILD
// RAMET: upstream omits this and relies on CBA/HEMTT side-effects that no
// longer apply; define it explicitly so config.cpp's `VERSION_CONFIG;` line
// expands to a valid `version = "x.y.z.w"; ...` triplet.
#define VERSION_CONFIG version = QUOTE(VERSION); versionStr = QUOTE(VERSION); versionAr[] = {VERSION_AR}

// Bumped from 1.88: addons/exporter/XEH_postInit.sqf uses ExtensionCallback (1.96+).
#define REQUIRED_VERSION 1.96
