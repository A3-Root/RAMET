/*
 * Author: Root
 * Description: Drop a multi-mode export that is still being set up.
 *              Clears the flags so the reused Grad_meh and OCAP options
 *              dialogs behave normally again the next time they are opened on
 *              their own.
 *
 * Public: No
 */
#include "..\script_component.hpp"

uiNamespace setVariable ["ramet_all_collecting", false];
uiNamespace setVariable ["ramet_all_pickerMode", nil];
uiNamespace setVariable ["ramet_all_optIndex", 0];
uiNamespace setVariable ["ramet_all_active", false];
uiNamespace setVariable ["ramet_all_running", false];
