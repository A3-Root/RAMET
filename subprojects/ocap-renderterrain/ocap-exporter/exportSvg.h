#pragma once

/*
 * Terrain SVG export through the game executable.
 *
 * The Arma 3 x64 executable exports the engine function behind the terrain SVG
 * export (the same one diag_exportTerrainSVG uses on the diagnostics build) as a
 * regular symbol, so it can be resolved with GetProcAddress on every branch.
 * The call runs synchronously on the calling (game) thread and blocks the game
 * until the SVG has been written.
 */

#include <stdbool.h>

#if defined(_WIN64)
#include <windows.h>

#define OCAP_EXPORT_SVG_SYMBOL "?ExportSVG@@YAXPEBD_N11111@Z"

typedef void (*ocapExportSvgFn)(const char *path, bool drawLocationNames, bool drawGrid,
                                bool drawContours, bool drawTreeObjects,
                                bool drawMountainHeightpoints, bool simpleRoads);

static inline ocapExportSvgFn ocapResolveExportSvg(void)
{
	HMODULE exe = GetModuleHandleA(NULL);
	if (exe == NULL)
	{
		return NULL;
	}
	return (ocapExportSvgFn)GetProcAddress(exe, OCAP_EXPORT_SVG_SYMBOL);
}

/* Returns 1 when the executable exposes the export function. */
static inline int ocapExportSvgAvailable(void)
{
	return ocapResolveExportSvg() != NULL ? 1 : 0;
}

/* Returns 0 on success, -1 when the export function is not available. */
static inline int ocapExportSvg(const char *path, int drawLocationNames, int drawGrid,
                                int drawContours, int drawTreeObjects,
                                int drawMountainHeightpoints, int simpleRoads)
{
	ocapExportSvgFn fn = ocapResolveExportSvg();
	if (fn == NULL)
	{
		return -1;
	}
	fn(path, drawLocationNames != 0, drawGrid != 0, drawContours != 0, drawTreeObjects != 0,
	   drawMountainHeightpoints != 0, simpleRoads != 0);
	return 0;
}
#else
static inline int ocapExportSvgAvailable(void)
{
	return 0;
}

static inline int ocapExportSvg(const char *path, int drawLocationNames, int drawGrid,
                                int drawContours, int drawTreeObjects,
                                int drawMountainHeightpoints, int simpleRoads)
{
	(void)path;
	(void)drawLocationNames;
	(void)drawGrid;
	(void)drawContours;
	(void)drawTreeObjects;
	(void)drawMountainHeightpoints;
	(void)simpleRoads;
	return -1;
}
#endif
