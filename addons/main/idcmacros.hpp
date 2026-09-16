#ifndef RAMET_MAIN_IDCMACROS_HPP
#define RAMET_MAIN_IDCMACROS_HPP

#define GRID_W (pixelW * pixelGrid)
#define GRID_H (pixelH * pixelGrid)
#ifndef QUOTE
#define QUOTE(var1) #var1
#endif
#define CENTER_X(w) (safezoneX + (safezoneW - w) / 2)
#define CENTER_Y(h) (safezoneY + (safezoneH - h) / 2)
#define SPACING 1

#define MAP_ITEM_W 30
#define MAP_ITEM_H 40

#define IDC_MAPITEM_BACKGROUND 1
#define IDC_MAPITEM_PICTURE 2
#define IDC_MAPITEM_NAME 3
#define IDC_MAPITEM_SELECTINDICATOR 4
#define IDC_MAPITEM_AUTHOR 5

#define IDC_DIALOG_CONTENT 742123

// Multi-mode export: which exporters to run, then the GMS-specific passes.
#define IDC_ALL_CHECK_GRAD 501
#define IDC_ALL_CHECK_GMS 502
#define IDC_ALL_CHECK_OCAP 503

#define IDC_ALL_CHECK_GMS_HIRES 512
#define IDC_ALL_CHECK_GMS_AERIAL 513

#endif
