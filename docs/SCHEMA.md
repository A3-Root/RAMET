# RAMET `map.json` — schema v `ramet-1`

`output/{world}/map.json` is the unified manifest the planner consumes. Old
OCAP-style fields are **not** preserved — the planner code is rewritten to
read this schema directly.

## Top-level keys

| Key            | Type         | Notes                                                                 |
| -------------- | ------------ | --------------------------------------------------------------------- |
| `schemaVersion`| `string`     | Always `"ramet-1"` for this generation.                               |
| `worldName`    | `string`     | CfgWorlds class (lowercase).                                          |
| `displayName`  | `string`     | Human label. Falls back to `worldName.title()`.                       |
| `worldSize`    | `number`     | Arma world dimension (m). From grad_meh `meta.json`.                  |
| `imageSize`    | `number`     | Pixel size of full-zoom raster. Used by planner's coord transform.    |
| `multiplier`   | `number`     | `imageSize / worldSize` — already in planner's `armaToLatLng`.        |
| `cellSize`     | `number`     | DEM cell size (m). 7.5 for most maps.                                 |
| `latitude`     | `number`     | Geographic lat (only for tooltip / attribution).                      |
| `longitude`    | `number`     | Geographic lon.                                                       |
| `attribution`  | `string`     | "Bohemia Interactive".                                                |
| `minZoom`      | `int`        | Lowest tile zoom level present.                                       |
| `maxZoom`      | `int`        | Highest tile zoom level present.                                      |
| `source`       | `string`     | `"grad_meh"`, `"ocap"`, or `"grad_meh+ocap"`.                          |
| `rasterLayers` | `array`      | See **rasterLayers** below.                                           |
| `vectorSource` | `object?`    | Omitted when no PMTiles was produced.                                 |
| `svgLayers`    | `array?`     | Omitted when no SVG slicing happened.                                 |
| `dem`          | `object?`    | `{ asc: "dem/dem.asc.gz", cellSize }`.                                |
| `preview`      | `string?`    | Relative path to preview PNG.                                         |

## rasterLayers[]

```jsonc
{
  "id":      "sat",                    // unique within manifest
  "path":    "tiles/sat/{z}/{x}/{y}.webp",
  "label":   "Satellite",              // user-facing
  "category":"base",                   // currently only "base"
  "ext":     "webp"                    // "png" | "webp"
}
```

Known raster layer ids: `sat`, `sat_dark`, `baked_sat`, `baked_sat_dark`, `topo`,
`topo_dark`, `baked_topo`, `baked_topo_dark`, `ingame` (in-game topographic), and
`ingame_aerial` (in-game orthographic "satellite" imagery, cherry-picked from GMS v2.2.0).
`ingame_aerial` is only present when the in-game export produced `aerial.png`.

## vectorSource

```jsonc
{
  "type": "pmtiles",
  "url":  "vector/features.pmtiles",
  "layers": [
    { "id": "road_main", "label": "Main Roads", "category": "transport", "default": true },
    { "id": "road",      "label": "Roads",      "category": "transport", "default": true  },
    { "id": "house",     "label": "Buildings",  "category": "structure", "default": false }
  ]
}
```

Layer ids map 1:1 to grad_meh GeoJSON file stems (`road_main.geojson` →
`road_main`). `category` is one of `transport | structure | terrain | labels | other`
and drives the planner's grouped overlay panel. `default: true` means the
layer is enabled on first paint.

`features.pmtiles` is served via HTTP Range requests; the planner uses the
`pmtiles` JS lib + `protomaps-leaflet` to render it client-side.

## svgLayers[]

```jsonc
{ "id": "roads_svg", "path": "svg/layers/roads.svg.gz", "label": "Roads (SVG HQ)" }
```

Gzipped. Served with `Content-Encoding: gzip`.

## Provenance — `source.json`

Companion file:

```jsonc
{
  "generatedAt": "2026-05-24T13:22:00Z",
  "grad_meh":    "/path/to/_intermediate/grad_meh/altis",
  "ocap_rt":     "/path/to/_intermediate/ocap_rt/altis",
  "tool":        "ramet.orchestrate"
}
```
