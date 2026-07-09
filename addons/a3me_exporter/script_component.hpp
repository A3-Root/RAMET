#define COMPONENT exporter
#include "\z\root_amet\addons\a3me_main\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE
// #define DEBUG_SYNCHRONOUS
// #define DEBUG_BACKEND

#ifdef DEBUG_ENABLED_CONNECT
    #define DEBUG_MODE_FULL
#endif
#ifdef DEBUG_SETTINGS_OTHER
    #define DEBUG_SETTINGS DEBUG_SETTINGS_CONNECT
#endif

#include "\z\root_amet\addons\a3me_main\script_macros.hpp"
