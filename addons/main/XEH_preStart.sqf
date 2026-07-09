/*
 * Author: Root
 * Description: CBA PreStart Event Handler for Root's AMET addon
 *              Computes and caches the diag-vs-stable binary flag as early
 *              as possible, before any spotlight tile condition or export
 *              menu check needs it. Logs productVersion once for tuning the
 *              diag detection heuristic.
 *
 * Public: No
 */

private _isDiag = (supportInfo "u:diag_exportTerrainSVG*") isNotEqualTo []
    || {(productVersion select 1) == "Arma3Diag"};

uiNamespace setVariable ["ramet_isDiagBuild", _isDiag];

diag_log text format ["[RAMET] preStart: isDiagBuild=%1 productVersion=%2", _isDiag, productVersion];
