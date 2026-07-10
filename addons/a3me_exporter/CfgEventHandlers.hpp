class Extended_PreStart_EventHandlers {
    class ADDON {
        init = QUOTE(call compile preprocessFileLineNumbers '\z\root_amet\addons\a3me_exporter\XEH_preStart.sqf');
    };
};
class Extended_PreInit_EventHandlers {
    class ADDON {
        init = QUOTE(call compile preprocessFileLineNumbers '\z\root_amet\addons\a3me_exporter\XEH_preInit.sqf');
    };
};
class Extended_PostInit_EventHandlers {
    class ADDON {
        init = QUOTE(call compile preprocessFileLineNumbers '\z\root_amet\addons\a3me_exporter\XEH_postInit.sqf');
    };
};
