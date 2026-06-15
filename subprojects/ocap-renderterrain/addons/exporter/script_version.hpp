#define MAJOR 1
#define MINOR 3
#define PATCH 0
#define BUILD 0

#define VERSION MAJOR.MINOR
#define VERSION_STR MAJOR.MINOR.PATCH.BUILD
#define VERSION_AR MAJOR,MINOR,PATCH,BUILD

#define VERSION_CONFIG version = VERSION; versionStr = QUOTE(VERSION_STR); versionAr[] = {VERSION_AR}
#define QUOTE(var1) #var1
