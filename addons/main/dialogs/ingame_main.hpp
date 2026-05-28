class RscText;
class RscListBox;
class RscButton;

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
            x = "safeZoneX + safeZoneW * 0.2";
            y = "safeZoneY + safeZoneH * 0.08";
            w = "safeZoneW * 0.6";
            h = "safeZoneH * 0.84";
            colorBackground[] = {0.13, 0.13, 0.13, 0.97};
            text = "";
        };
        class TitleBar: RscText {
            idc = -1;
            x = "safeZoneX + safeZoneW * 0.2";
            y = "safeZoneY + safeZoneH * 0.08";
            w = "safeZoneW * 0.6";
            h = "safeZoneH * 0.055";
            colorBackground[] = {0.08, 0.28, 0.50, 0.95};
            text = "";
        };
    };

    class Controls {
        class Title: RscText {
            idc = -1;
            text = "RAMET — In-Game Export (GMS)";
            x = "safeZoneX + safeZoneW * 0.205";
            y = "safeZoneY + safeZoneH * 0.087";
            w = "safeZoneW * 0.59";
            h = "safeZoneH * 0.04";
            style = 0;
            colorBackground[] = {0, 0, 0, 0};
            colorText[] = {1, 1, 1, 1};
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 25)";
            font = "RobotoCondensedBold";
        };
        class Subtitle: RscText {
            idc = -1;
            text = "Select worlds to export (Ctrl+Click to multi-select):";
            x = "safeZoneX + safeZoneW * 0.205";
            y = "safeZoneY + safeZoneH * 0.143";
            w = "safeZoneW * 0.59";
            h = "safeZoneH * 0.033";
            style = 0;
            colorBackground[] = {0, 0, 0, 0};
            colorText[] = {0.8, 0.8, 0.8, 1};
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 30)";
            font = "RobotoCondensed";
        };
        class WorldList: RscListBox {
            idc = 1010;
            x = "safeZoneX + safeZoneW * 0.205";
            y = "safeZoneY + safeZoneH * 0.18";
            w = "safeZoneW * 0.59";
            h = "safeZoneH * 0.56";
            rowHeight = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 22)";
            colorBackground[] = {0.08, 0.08, 0.08, 0.95};
            colorText[] = {0.9, 0.9, 0.9, 1};
            colorSelectBackground[] = {0.18, 0.45, 0.75, 0.85};
            colorSelect[] = {1, 1, 1, 1};
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 28)";
            font = "RobotoCondensed";
        };
        class BtnSelectAll: RscButton {
            idc = 1011;
            text = "Select All";
            x = "safeZoneX + safeZoneW * 0.205";
            y = "safeZoneY + safeZoneH * 0.755";
            w = "safeZoneW * 0.14";
            h = "safeZoneH * 0.038";
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 30)";
            action = "private _lb = (findDisplay 9850) displayCtrl 1010; for '_i' from 0 to (lbSize _lb - 1) do { _lb lbSetSelected [_i, true]; };";
        };
        class BtnClear: RscButton {
            idc = 1012;
            text = "Clear";
            x = "safeZoneX + safeZoneW * 0.355";
            y = "safeZoneY + safeZoneH * 0.755";
            w = "safeZoneW * 0.09";
            h = "safeZoneH * 0.038";
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 30)";
            action = "private _lb = (findDisplay 9850) displayCtrl 1010; for '_i' from 0 to (lbSize _lb - 1) do { _lb lbSetSelected [_i, false]; };";
        };
        class BtnExport: RscButton {
            idc = 1;
            text = "EXPORT";
            x = "safeZoneX + safeZoneW * 0.665";
            y = "safeZoneY + safeZoneH * 0.862";
            w = "safeZoneW * 0.09";
            h = "safeZoneH * 0.044";
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 28)";
            action = "closeDialog 1;";
        };
        class BtnCancel: RscButton {
            idc = 2;
            text = "Cancel";
            x = "safeZoneX + safeZoneW * 0.565";
            y = "safeZoneY + safeZoneH * 0.862";
            w = "safeZoneW * 0.09";
            h = "safeZoneH * 0.044";
            size = "((((safeZoneW / safeZoneH) min 1.2) / 1.2) / 30)";
            action = "closeDialog 0;";
        };
    };
};
