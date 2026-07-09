/*
 * Author: Root
 * Description: Returns whether the running binary is the Arma diagnostic exe.
 *              Reads the uiNamespace cache set by XEH_preStart; computes and
 *              caches it if preStart hasn't run yet (e.g. called too early).
 *
 * Public: Yes
 *
 * Usage:
 *   _isDiag = [] call ramet_fnc_isDiagBuild;
 */

#include "..\script_component.hpp"

if (isNil {uiNamespace getVariable "ramet_isDiagBuild"}) then {
    uiNamespace setVariable ["ramet_isDiagBuild",
        (supportInfo "u:diag_exportTerrainSVG*") isNotEqualTo []
        || {(productVersion select 1) == "Arma3Diag"}
    ];
};

uiNamespace getVariable ["ramet_isDiagBuild", false]
