#include "script_version.hpp"

#define QUOTE(var1) #var1
#define DOUBLES(var1,var2) ##var1##_##var2
#define TRIPLES(var1,var2,var3) ##var1##_##var2##_##var3
#define ADDON DOUBLES(PREFIX,COMPONENT)
#define QADDON QUOTE(ADDON)
#define QQADDON QUOTE(QADDON)

#define PATHTOF(var1) \MAINPREFIX\PREFIX\addons\COMPONENT\var1
#define QPATHTOF(var1) QUOTE(PATHTOF(var1))

#define VERSION_CONFIG version = QUOTE(VERSION); versionStr = QUOTE(VERSION); versionAr[] = {VERSION_AR}

#ifdef DISABLE_COMPILE_CACHE
    #ifdef PREP
        #undef PREP
    #endif
    #define PREP(fncName) DFUNC(fncName) = compile preprocessFileLineNumbers QPATHTOF(functions\DOUBLES(fn,fncName).sqf)
#else
    #ifdef PREP
        #undef PREP
    #endif
    #define PREP(fncName) [QPATHTOF(functions\DOUBLES(fn,fncName).sqf), QFUNC(fncName)] call CBA_fnc_compileFunction
#endif

#define PREP_MODULE(folder) [QPATHTOF(folder\script_component.hpp), QFUNC(folder)] call CBA_fnc_compileFunction

#define DFUNC(var1) TRIPLES(ADDON,fnc,var1)
#define QFUNC(var1) QUOTE(DFUNC(var1))
#define FUNC(var1) DFUNC(var1)

#define GVAR(var1) DOUBLES(ADDON,var1)
#define QGVAR(var1) QUOTE(GVAR(var1))
#define EGVAR(var1,var2) TRIPLES(PREFIX,var1,var2)
#define QEGVAR(var1,var2) QUOTE(EGVAR(var1,var2))

#define COMPILE_FILE(var1) compile preprocessFileLineNumbers QPATHTOF(var1.sqf)
