if (!call (uiNamespace getVariable ["INTERCEPT_BOOT_DONE",{false}])) then {
    #include "\z\root_amet\addons\intercept_core\boot.sqf"
    uiNamespace setVariable ['INTERCEPT_BOOT_DONE', compileFinal 'true'];
};

if (isNil {_this}) then  {
    call compile preprocessFileLineNumbers '\z\root_amet\addons\intercept_core\lib.sqf';
    call compile preprocessFileLineNumbers "\A3\functions_f\initFunctions.sqf";
} else {
    _this call compile preprocessFileLineNumbers "\A3\functions_f\initFunctions.sqf";
};
