#include "script_version.hpp"

#define VERSION MAJOR.MINOR.PATCH-BUILD
#define VERSION_AR MAJOR,MINOR,PATCH,BUILD

#define VERSION_CONFIG version = #VERSION; versionStr = #VERSION; versionAr[] = {VERSION_AR}
