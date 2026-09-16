/*
 * Author: Root
 * Description: onLoad handler for the ramet_all_gms_config dialog.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 *
 * Public: No
 */
#include "../idcmacros.hpp"

params ["_display"];

private _options = uiNamespace getVariable ["ramet_all_opt_ingame", [true, true]];
_options params [["_hires", true], ["_aerial", true]];

(_display displayCtrl IDC_ALL_CHECK_GMS_HIRES) cbSetChecked _hires;
(_display displayCtrl IDC_ALL_CHECK_GMS_AERIAL) cbSetChecked _aerial;
