class RscText;
class RscButton;
class ctrlControlsGroupNoHScrollbars;

class ramet_ingame_main {
    idd = 9850;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "call ramet_fnc_ingameMain_onLoad;";
    onUnLoad = "call ramet_fnc_ingameMain_onUnLoad;";

    class ControlsBackground {
        class Overlay: RscText {
            idc = -1;
            x = "safeZoneXAbs";
            y = "safeZoneY";
            w = "safeZoneWAbs";
            h = "safeZoneH";
            colorBackground[] = {0, 0, 0, 0.7};
            text = "";
        };
        class Panel: RscText {
            idc = -1;
            x = "safeZoneX + safeZoneW * 0.1";
            y = "safeZoneY + safeZoneH * 0.05";
            w = "safeZoneW * 0.8";
            h = "safeZoneH * 0.88";
            colorBackground[] = {0.13, 0.13, 0.13, 0.97};
            text = "";
        };
        class TitleBar: RscText {
            idc = -1;
            x = "safeZoneX + safeZoneW * 0.1";
            y = "safeZoneY + safeZoneH * 0.05";
            w = "safeZoneW * 0.8";
            h = "safeZoneH * 0.055";
            colorBackground[] = {0.08, 0.28, 0.50, 0.95};
            text = "";
        };
    };

    class Controls {
        class Title: RscText {
            idc = -1;
            text = "RAMET — In-Game Export (GMS)";
            x = "safeZoneX + safeZoneW * 0.105";
            y = "safeZoneY + safeZoneH * 0.057";
            w = "safeZoneW * 0.79";
            h = "safeZoneH * 0.04";
            style = 0;
            colorBackground[] = {0, 0, 0, 0};
            colorText[] = {1, 1, 1, 1};
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 25)";
            font = "RobotoCondensedBold";
        };
        class MapTiles: ctrlControlsGroupNoHScrollbars {
            idc = 742123;
            x = "safeZoneX + safeZoneW * 0.1";
            y = "safeZoneY + safeZoneH * 0.115";
            w = "safeZoneW * 0.8";
            h = "safeZoneH * 0.75";
            class Controls {};
        };
        class BtnExport: RscButton {
            idc = 1;
            text = "EXPORT";
            x = "safeZoneX + safeZoneW * 0.665";
            y = "safeZoneY + safeZoneH * 0.882";
            w = "safeZoneW * 0.09";
            h = "safeZoneH * 0.044";
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 28)";
            action = "closeDialog 1;";
        };
        class BtnCancel: RscButton {
            idc = 2;
            text = "Cancel";
            x = "safeZoneX + safeZoneW * 0.565";
            y = "safeZoneY + safeZoneH * 0.882";
            w = "safeZoneW * 0.09";
            h = "safeZoneH * 0.044";
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 30)";
            action = "closeDialog 0;";
        };
    };
};
