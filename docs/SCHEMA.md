# RAMET `map.json` schema

`RAMET_Output/processed/{world}/map.json` is written in two stages:

- `tools/merge_outputs.py` creates the base manifest from the available source
  directories.
- `tools/orchestrate.py` adds rendered layers, final zoom bounds, and the final
  raster metadata before writing the file.

`source.json` sits next to it and records where the merged output came from.
For `tools/orchestrate.py --from-reference`, the same schema is written under
`output/{world}/` instead.

## Top-level keys

| Key            | Type      | Notes |
| -------------- | --------- | ----- |
| `schemaVersion`| `string`   | Always `"ramet-1"`. |
| `worldName`    | `string`   | Lowercase `CfgWorlds` class name. |
| `displayName`  | `string`   | Human label. Falls back to `world.title()`. |
| `worldSize`    | `number`   | World size in meters. |
| `imageSize`    | `number`   | Final canonical raster size in pixels. `orchestrate.py` recomputes this from the final `maxZoom`. |
| `multiplier`   | `number`   | `imageSize / worldSize`. Used by the planner coordinate transform. |
| `cellSize`     | `number?`  | DEM cell size in meters. |
| `latitude`     | `number?`  | Anchor latitude. |
| `longitude`    | `number?`  | Anchor longitude. |
| `attribution`  | `string`   | Currently `"Bohemia Interactive"`. |
| `minZoom`      | `number`   | Lowest raster zoom present after verification. |
| `maxZoom`      | `number`   | Highest raster zoom present after verification. |
| `source`       | `string`   | Input family summary such as `grad_meh`, `ocap`, or `ocap+grad_meh` in detection order. This is a merge summary, not a full provenance record. |
| `rasterLayers` | `array`    | Ordered list of base-layer variants. |
| `vectorSource` | `object?`  | Present when PMTiles was built. |
| `svgLayers`    | `array?`   | Present when SVG slicing succeeded. |
| `dem`          | `object?`  | Present when a DEM exists. |
| `terrain3d`    | `object?`  | Present when the planner 3D data was built. |
| `preview`      | `string?`  | Relative preview PNG path, or `null` when absent. |

## `rasterLayers[]`

Each raster layer object has:

| Key | Type | Notes |
| --- | --- | --- |
| `id` | `string` | Stable layer identifier used by the planner and tile route. |
| `path` | `string` | Relative tile path template, e.g. `tiles/topo/{z}/{x}/{y}.png`. |
| `label` | `string` | User-facing name. |
| `category` | `string` | Currently `base` for raster layers. |
| `ext` | `string` | `png` or `webp`. |
| `minZoom` | `number` | Lowest zoom level actually present on disk. |
| `maxZoom` | `number` | Highest zoom level actually present on disk. |

Current layer ids can include:

- `sat`
- `sat_dark`
- `baked_sat`
- `baked_sat_dark`
- `topo`
- `topo_dark`
- `baked_topo`
- `baked_topo_dark`
- `ingame`
- `ingame_aerial`
- `topoRelief`
- `colorRelief`

The exact set depends on which source families were present for that world. In
particular, `topoDark` from the ocap renderer is normalized to `topo_dark`, and
the imported ocap raster variants keep their camelCase ids (`topoRelief`,
`colorRelief`).

## `vectorSource`

```jsonc
{
  "type": "pmtiles",
  "url": "vector/features.pmtiles",
  "layers": [
    { "id": "road_main", "label": "Main Roads", "category": "transport", "default": true },
    { "id": "road", "label": "Roads", "category": "transport", "default": true },
    { "id": "house", "label": "Buildings", "category": "structure", "default": false }
  ]
}
```

Notes:

- `url` is relative to `RAMET_Output/processed/{world}/`.
- Layer ids map to the grad_meh GeoJSON stems.
- `category` is one of `transport`, `structure`, `terrain`, `labels`, or
  `other`.
- `default: true` means the layer starts enabled.

The planner serves the bundle with HTTP range support and renders it through
`pmtiles` + `protomaps-leaflet`.

## `svgLayers[]`

```jsonc
{ "id": "roads_svg", "path": "svg/layers/roads.svg.gz", "label": "Roads (SVG HQ)" }
```

Each entry points at a gzipped SVG file and is served with
`Content-Encoding: gzip`.

## `dem`

```jsonc
{ "asc": "dem/dem.asc.gz", "cellSize": 7.5 }
```

`dem.asc.gz` is optional, but when present the planner can use it for terrain or
debug tooling.

## `terrain3d`

```jsonc
{ "schema": "ramet-3d-2", "path": "3d/terrain.json", "hasObjects": true,
  "hasVoxel": true, "hasMesh": true }
```

Written by `tools/build_3d.py` from the DEM and the grad_meh `3d/` export
(`models.json`, `models.bin`, `objects.bin`). `3d/terrain.json` describes:

- `heights`: `cellSize`, grid `rows`/`cols`, quantisation `min`/`max`,
  `overview` (`3d/height_overview.bin`, whole map, `stride` cells between
  samples, last row/column clamped to the grid edge) and `chunks`
  (`3d/height/{cx}_{cy}.bin`, `cells + 1` samples per side, `size` metres).
  Heights are uint16 little-endian, rows south to north:
  `h = min + q / 65535 * (max - min)`; sample `(i, j)` is at world
  `(i * cellSize, j * cellSize)`.
- `objects` (only with grad_meh data): `models` (`3d/models.json`, one entry per
  used model with `category`, visual `bboxMin`/`bboxMax` and offsets into
  `3d/models.bin`) and `path` (`3d/objects/{cx}_{cy}.bin`, 52-byte records:
  uint32 model id, float32 east, north, height ASL, float32[9] model axes `_0`,
  `_1`, `_2`). Objects use the same chunk grid as the heights.

  Each model carries up to two geometry streams in `3d/models.bin`, both stored
  as float32 xyz vertices followed by uint32 triangle indices in model space
  (x right, y up, z forward):

  | Stream | Offsets | Source |
  | --- | --- | --- |
  | Mesh | `vertexOffset`/`vertexCount`, `indexOffset`/`indexCount` | the model's most detailed visual LOD, or its Geometry LOD when it has no visual one |
  | Voxel | `voxelVertexOffset`/`voxelVertexCount`, `voxelIndexOffset`/`voxelIndexCount` | a blocky proxy of that mesh at `voxelSize` metres per cell |

  A count of 0 means the model does not carry that stream: a model over
  `--mesh-budget` triangles ships voxel-only, and a model the voxelizer could
  not process ships mesh-only. `objects.hasMesh`/`objects.hasVoxel` report which
  streams exist for the map as a whole, alongside `meshModels`, `voxelModels`,
  `meshBytes`, `voxelBytes`, `meshTriangleBudget` and `meshOverBudget`.

  Schema `ramet-3d-1` had the mesh stream only, taken from the Geometry LOD, and
  no voxel fields. Readers should treat the voxel fields as absent there.

## `source.json`

Companion provenance file:

```jsonc
{
  "generatedAt": "2026-05-24T13:22:00Z",
  "grad_meh": "/path/to/grad_meh/altis",
  "ocap_raw": "/path/to/ocap_exporter/altis",
  "ocap_rendered": "/path/to/RAMET_Output/raw/altis/ocap-rt",
  "tool": "ramet.orchestrate"
}
```

`grad_meh`, `ocap_raw`, and `ocap_rendered` may be `null` when the
corresponding source family was not used. `generatedAt` and `tool` are always
set. The current schema does not store a separate `ingame` provenance path.

## Practical notes

- `vectorSource` and `svgLayers` are omitted entirely when those stages do not
  run.
- `imageSize` and `multiplier` are recomputed from the final raster pyramid, so
  they reflect the actual output on disk.
- `preview` is written as `null` when no preview PNG exists.
- In in-game-only post-process runs, `tools/orchestrate.py` preserves the
  existing manifest and layers the GMS raster on top rather than rebuilding the
  manifest from scratch.
