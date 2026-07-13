/*
 * Author: Root
 * Description: CBA PreStart Event Handler for Root's AMET addon
 *              Computes and caches the diag-vs-stable binary flag as early
 *              as possible, before any spotlight tile condition or export
 *              menu check needs it. Logs the RAMET and Arma versions once.
 *
 * Public: No
 */

private _isDiag = (supportInfo "u:diag_exportTerrainSVG*") isNotEqualTo []
    || {(productVersion select 1) == "Arma3Diag"};
private _rametVersion = getText (configFile >> "CfgPatches" >> "root_amet" >> "versionStr");

uiNamespace setVariable ["ramet_isDiagBuild", _isDiag];

diag_log text format ["[RAMET] preStart: version=%1 isDiagBuild=%2 productVersion=%3", _rametVersion, _isDiag, productVersion];
