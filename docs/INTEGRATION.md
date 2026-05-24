# Planner integration — JSOC-OPS-Warlords

RAMET produces `output/{world}/` directly drop-in compatible with the new
planner schema. Server- and client-side code in
`JSOC-OPS-Warlords/server/warlords/` is rewritten (no backward-compat to old
OCAP-style map.json).

Patches applied by this change set are documented here so future updates can
re-derive them.

## Server — `server/warlords/server.py`

### Rewritten

- `_load_map_meta(map_name)` — unchanged signature, but the file it loads now follows the `ramet-1` schema (see `docs/SCHEMA.md`).
- `_enrich_map_meta(meta, map_path)` — drops the OCAP-style fields it used to inject (`hasBaseTiles`, scanned variants from filesystem). All raster/vector/svg layer info now comes straight from `map.json`. Live scanning is no longer the source of truth.
- `serve_tile` — accepts a `variant` query param resolved against `rasterLayers[].id` from the world's manifest. Picks the file extension from the layer entry (`png` or `webp`). Streams with the correct `Content-Type`.
- `/api/v1/maps` — emits the merged manifests directly; no zoom scanning.
- `/api/v1/config` — same; falls back to defaults only if `map.json` is missing entirely.

### New endpoints

- `GET /tiles/<world>/vector/features.pmtiles` → `serve_pmtiles(world)` — `send_file` with `mimetype="application/octet-stream"`, `as_attachment=False`, `conditional=True` (Flask handles HTTP Range natively when `conditional=True`).
- `GET /tiles/<world>/svg/layers/<name>.svg.gz` → `serve_svg_layer(world, name)` — sends with `Content-Type: image/svg+xml` + `Content-Encoding: gzip` (file is already gzipped on disk).

### Removed

- Per-variant `_scan_tile_zoom` / `_scan_map_variants` walks. Manifest is authoritative.

## Frontend — `server/warlords/static/js/warlords.map.js`

### Tile layer init (~line 94-118)

```js
const rasterLayers = mapMeta.rasterLayers || [];
const layerObjects = {};
for (const r of rasterLayers) {
  layerObjects[r.id] = L.tileLayer(
    `/tiles/${mapName}/${r.path.replace('{z}/{x}/{y}.' + r.ext, '{z}/{x}/{y}.' + (r.ext || 'png'))}`,
    {
      minZoom: mapMeta.minZoom,
      maxZoom: mapMeta.maxZoom,
      tileSize: 256,
      attribution: mapMeta.attribution,
    }
  );
}
// pick base
const initial = rasterLayers.find(r => r.id === 'topo') || rasterLayers[0];
layerObjects[initial.id].addTo(map);
```

### PMTiles vector overlay

Load deps in `index.html`:

```html
<script src="https://unpkg.com/pmtiles@2.11.0/dist/index.js"></script>
<script src="https://unpkg.com/protomaps-leaflet@1.24.0/dist/protomaps-leaflet.min.js"></script>
```

Then in `warlords.map.js`:

```js
if (mapMeta.vectorSource && mapMeta.vectorSource.type === 'pmtiles') {
  const p = new pmtiles.PMTiles(`/tiles/${mapName}/${mapMeta.vectorSource.url}`);
  const vectorLayers = {};
  for (const lyr of mapMeta.vectorSource.layers) {
    vectorLayers[lyr.id] = protomapsL.leafletLayer({
      url: p,
      paint_rules: defaultPaintFor(lyr),
      label_rules: lyr.category === 'labels' ? defaultLabelFor(lyr) : [],
    });
    if (lyr.default) vectorLayers[lyr.id].addTo(map);
  }
}
```

### Layer-control panel

Pure user-defined stack:

- **Base** — radio over `rasterLayers`.
- **Vector overlays** — independent checkboxes over `vectorSource.layers`, grouped by `category` (transport / structure / terrain / labels / other).
- **SVG overlays** — checkboxes over `svgLayers` (`<img>` overlays via `L.imageOverlay`, or inline `<svg>` via fetch-decompress).

Common presets ("Topographic", "Satellite", "Hybrid") are one-click stack
toggles, not a mode dropdown — the underlying layer state is always the source of truth.

### Coord transform

`armaToLatLng` / `latLngToArma` (~line 338-352) **unchanged**. Manifest preserves
`imageSize` and `multiplier` exactly as the old format used them, so every
existing marker/drawing stays in place after redeploy.

## Drawing / marker compatibility

`Leaflet.draw`, marker `FeatureGroup`s, GeoJSON I/O — untouched. New base/overlay layers
slot in **beneath** the editable FeatureGroups via Leaflet's default z-order
(panes if you need explicit control).

## Templates — `server/warlords/templates/`

Add the two `<script>` tags to whichever HTML loads `warlords.map.js`.
If the planner ships the libs vendored under `static/lib/`, drop them there
and use a relative `src=` instead of unpkg — avoids CSP `connect-src` widening.

## CSP note

PMTiles + protomaps-leaflet don't need `connect-src` widening if everything
is same-origin. Keep the existing `connect-src 'self'` directive.

## Smoke test

1. Deploy `output/stratis/` to planner.
2. Restart planner, open browser.
3. Base layer switcher exposes Satellite + Topo + ColorRelief (whatever the manifest declares).
4. Toggle vector overlays — roads/forests/locations render in correct world coords.
5. Drop a marker at a known Arma coordinate; it lands on the correct building.
6. Confirm Leaflet.draw still works on top of the new base + overlays.
