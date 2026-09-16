"""Build the 3D terrain + object data consumed by the web planner's 3D view.

Reads:
  <world_out>/dem/dem.asc.gz          (ESRI ASCII grid, rows north -> south)
  <grad_dir>/3d/models.json           (optional, written by grad_meh)
  <grad_dir>/3d/models.bin
  <grad_dir>/3d/objects.bin

Writes <world_out>/3d/:
  terrain.json                 layout + quantisation of everything below
  height_overview.bin          uint16 LE heights, whole map, rows south -> north
  height/<cx>_<cy>.bin         uint16 LE heights, (chunkCells+1)^2 samples per chunk
  models.json / models.bin     used models: float32 xyz vertices + uint32 triangle indices
  objects/<cx>_<cy>.bin        52-byte records: uint32 model id, float32 x, y, z (world,
                               y = north, z = height ASL), float32[9] model axes (_0, _1, _2)

Heights are quantised as h = min + q / 65535 * (max - min). Sample (i, j) of the
full grid lies at world (i * cellSize, j * cellSize).
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
from pathlib import Path

import numpy as np

SCHEMA = "ramet-3d-2"
CHUNK_CELLS = 128
OVERVIEW_MAX_SAMPLES = 1025
# Models whose largest visual extent is below this (metres) are skipped: clutter,
# helpers and proxies that are invisible at planner zoom levels.
MIN_MODEL_EXTENT = 0.75
# Triangles per model kept in the real-mesh stream. A model over budget ships its
# voxel proxy only, so one dense interior LOD cannot inflate models.bin.
DEFAULT_MESH_BUDGET = 20000

OBJECT_DTYPE = np.dtype([("model", "<u4"), ("t", "<f4", (12,))])

_TREE = {"tree", "small tree"}
_BUSH = {"bush"}
_ROCK = {"rock", "rocks"}
_WALL = {"wall", "fence"}
_BUILDING = {"house", "building", "bunker", "chapel", "church", "fortress", "fuelstation",
             "hospital", "lighthouse", "ruin", "stack", "tourism", "transmitter",
             "view-tower", "watertower", "busstop", "quay", "powersolar", "powerwave",
             "powerwind", "shipwreck", "fountain", "cross"}


def _category(map_type: str, path: str) -> str:
    t = (map_type or "").strip().lower()
    if t in _TREE:
        return "tree"
    if t in _BUSH:
        return "bush"
    if t in _ROCK:
        return "rock"
    if t in _WALL:
        return "wall"
    if t in _BUILDING:
        return "building"
    p = path.lower().replace("/", "\\")
    if "\\vegetation" in p or "\\plants" in p or "\\tree" in p:
        return "tree" if "\\bush" not in p else "bush"
    return "other"


def _read_dem(path: Path) -> tuple[np.ndarray, float]:
    """Parse the ASC grid. Returns (heights[rows south -> north, cols west -> east], cellsize)."""
    import gzip
    opener = gzip.open if path.suffix == ".gz" else open
    header: dict[str, float] = {}
    with opener(path, "rt", encoding="ascii") as fh:
        while True:
            pos_line = fh.readline()
            parts = pos_line.split()
            if len(parts) == 2 and parts[0].lower() in {"ncols", "nrows", "xllcorner", "yllcorner",
                                                         "cellsize", "nodata_value"}:
                header[parts[0].lower()] = float(parts[1])
                continue
            rest = pos_line + fh.read()
            break
    ncols = int(header["ncols"])
    nrows = int(header["nrows"])
    values = np.array(rest.split(), dtype=np.float32)
    if values.size != ncols * nrows:
        raise ValueError(f"DEM has {values.size} samples, expected {ncols * nrows}")
    grid = values.reshape(nrows, ncols)
    grid[grid == header.get("nodata_value", -9999.0)] = 0.0
    return np.ascontiguousarray(grid[::-1]), float(header["cellsize"])


def _quantise(values: np.ndarray, hmin: float, hmax: float) -> np.ndarray:
    span = max(hmax - hmin, 1e-6)
    q = np.rint((values - hmin) / span * 65535.0)
    return np.clip(q, 0, 65535).astype("<u2")


def _write_heights(grid: np.ndarray, cellsize: float, out_dir: Path) -> dict:
    rows, cols = grid.shape
    hmin = float(grid.min())
    hmax = float(grid.max())

    stride = max(1, math.ceil((max(rows, cols) - 1) / (OVERVIEW_MAX_SAMPLES - 1)))
    ys = np.arange(0, rows, stride)
    xs = np.arange(0, cols, stride)
    if ys[-1] != rows - 1:
        ys = np.append(ys, rows - 1)
    if xs[-1] != cols - 1:
        xs = np.append(xs, cols - 1)
    overview = grid[np.ix_(ys, xs)]
    (out_dir / "height_overview.bin").write_bytes(_quantise(overview, hmin, hmax).tobytes())

    height_dir = out_dir / "height"
    height_dir.mkdir(parents=True, exist_ok=True)
    chunks_x = math.ceil((cols - 1) / CHUNK_CELLS)
    chunks_y = math.ceil((rows - 1) / CHUNK_CELLS)
    # Pad by edge replication so every chunk has CHUNK_CELLS + 1 samples per side.
    padded = np.pad(grid, ((0, chunks_y * CHUNK_CELLS + 1 - rows), (0, chunks_x * CHUNK_CELLS + 1 - cols)),
                    mode="edge")
    for cy in range(chunks_y):
        for cx in range(chunks_x):
            block = padded[cy * CHUNK_CELLS: cy * CHUNK_CELLS + CHUNK_CELLS + 1,
                           cx * CHUNK_CELLS: cx * CHUNK_CELLS + CHUNK_CELLS + 1]
            (height_dir / f"{cx}_{cy}.bin").write_bytes(_quantise(block, hmin, hmax).tobytes())

    return {
        "cellSize": cellsize,
        "rows": rows,
        "cols": cols,
        "min": hmin,
        "max": hmax,
        "overview": {
            "path": "3d/height_overview.bin",
            "rows": int(len(ys)),
            "cols": int(len(xs)),
            # Sample positions are not uniform at the far edge; the index lists keep it exact.
            "stride": stride,
        },
        "chunks": {
            "path": "3d/height/{cx}_{cy}.bin",
            "cells": CHUNK_CELLS,
            "countX": chunks_x,
            "countY": chunks_y,
            "size": CHUNK_CELLS * cellsize,
        },
    }


def _write_objects(raw_3d: Path, chunk_size_m: float, chunks_x: int, chunks_y: int, out_dir: Path,
                   mesh_budget: int = DEFAULT_MESH_BUDGET) -> dict | None:
    meta_path = raw_3d / "models.json"
    models_bin = raw_3d / "models.bin"
    objects_bin = raw_3d / "objects.bin"
    if not (meta_path.exists() and models_bin.exists() and objects_bin.exists()):
        return None

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    raw_models = meta.get("models", [])
    mesh_blob = np.memmap(models_bin, dtype=np.uint8, mode="r") if models_bin.stat().st_size else None
    objects = np.fromfile(objects_bin, dtype=OBJECT_DTYPE)

    keep_model = np.zeros(len(raw_models) + 1, dtype=bool)
    for idx, m in enumerate(raw_models):
        bmin = np.array(m.get("bboxMin", [0, 0, 0]), dtype=np.float32)
        bmax = np.array(m.get("bboxMax", [0, 0, 0]), dtype=np.float32)
        keep_model[idx] = float(np.max(bmax - bmin)) >= MIN_MODEL_EXTENT
    model_ids = objects["model"]
    valid = model_ids < len(raw_models)
    objects = objects[valid]
    objects = objects[keep_model[objects["model"]]]

    used = np.unique(objects["model"])
    remap = np.full(len(raw_models), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))

    out_models = []
    mesh_bytes = 0
    voxel_bytes = 0
    mesh_models = 0
    voxel_models = 0
    over_budget = 0
    with open(out_dir / "models.bin", "wb") as fh:
        offset = 0

        def copy_stream(src_v_off: int, v_count: int, src_i_off: int, i_count: int) -> tuple[int, int, int, int]:
            """Copy one vertex+index pair out of the raw blob. Returns the new offsets."""
            nonlocal offset
            verts = bytes(mesh_blob[src_v_off: src_v_off + v_count * 12])
            idx = bytes(mesh_blob[src_i_off: src_i_off + i_count * 4])
            v_at = offset
            fh.write(verts)
            offset += len(verts)
            i_at = offset
            fh.write(idx)
            offset += len(idx)
            return v_at, v_count, i_at, i_count

        for new_id, old_id in enumerate(used.tolist()):
            m = raw_models[old_id]
            v_count = int(m.get("vertexCount", 0))
            i_count = int(m.get("indexCount", 0))
            vox_v_count = int(m.get("voxelVertexCount", 0))
            vox_i_count = int(m.get("voxelIndexCount", 0))
            entry = {
                "id": new_id,
                "path": m.get("path", ""),
                "category": _category(m.get("mapType", ""), m.get("path", "")),
                "bboxMin": m.get("bboxMin", [0, 0, 0]),
                "bboxMax": m.get("bboxMax", [0, 0, 0]),
                "vertexOffset": 0, "vertexCount": 0, "indexOffset": 0, "indexCount": 0,
                "voxelVertexOffset": 0, "voxelVertexCount": 0,
                "voxelIndexOffset": 0, "voxelIndexCount": 0,
                "voxelSize": float(m.get("voxelSize", 0.0)),
            }
            if mesh_blob is not None and v_count and i_count:
                if mesh_budget and i_count // 3 > mesh_budget and vox_v_count and vox_i_count:
                    # Too dense to ship; the voxel proxy below stands in for it.
                    over_budget += 1
                else:
                    before = offset
                    (entry["vertexOffset"], entry["vertexCount"],
                     entry["indexOffset"], entry["indexCount"]) = copy_stream(
                        int(m["vertexOffset"]), v_count, int(m["indexOffset"]), i_count)
                    mesh_bytes += offset - before
                    mesh_models += 1
            if mesh_blob is not None and vox_v_count and vox_i_count:
                before = offset
                (entry["voxelVertexOffset"], entry["voxelVertexCount"],
                 entry["voxelIndexOffset"], entry["voxelIndexCount"]) = copy_stream(
                    int(m["voxelVertexOffset"]), vox_v_count, int(m["voxelIndexOffset"]), vox_i_count)
                voxel_bytes += offset - before
                voxel_models += 1
            out_models.append(entry)
    (out_dir / "models.json").write_text(json.dumps(out_models), encoding="utf-8")

    t = objects["t"]
    records = np.empty(len(objects), dtype=np.dtype([("model", "<u4"), ("pos", "<f4", (3,)), ("axes", "<f4", (9,))]))
    records["model"] = remap[objects["model"]].astype("<u4")
    records["pos"][:, 0] = t[:, 9]   # east
    records["pos"][:, 1] = t[:, 11]  # north
    records["pos"][:, 2] = t[:, 10]  # height ASL
    records["axes"] = t[:, 0:9]

    cx = np.clip((records["pos"][:, 0] // chunk_size_m).astype(np.int64), 0, max(chunks_x - 1, 0))
    cy = np.clip((records["pos"][:, 1] // chunk_size_m).astype(np.int64), 0, max(chunks_y - 1, 0))
    key = cy * max(chunks_x, 1) + cx
    order = np.argsort(key, kind="stable")
    records = records[order]
    key = key[order]
    objects_dir = out_dir / "objects"
    objects_dir.mkdir(parents=True, exist_ok=True)
    boundaries = np.flatnonzero(np.diff(key)) + 1
    starts = np.concatenate(([0], boundaries)) if len(key) else np.array([], dtype=np.int64)
    ends = np.concatenate((boundaries, [len(key)])) if len(key) else np.array([], dtype=np.int64)
    counts: dict[str, int] = {}
    for s, e in zip(starts.tolist(), ends.tolist()):
        k = int(key[s])
        name = f"{k % max(chunks_x, 1)}_{k // max(chunks_x, 1)}"
        (objects_dir / f"{name}.bin").write_bytes(records[s:e].tobytes())
        counts[name] = e - s

    return {
        "models": "3d/models.json",
        "modelMesh": "3d/models.bin",
        "path": "3d/objects/{cx}_{cy}.bin",
        "recordBytes": records.dtype.itemsize,
        "count": int(len(records)),
        "chunkCounts": counts,
        "hasMesh": mesh_models > 0,
        "hasVoxel": voxel_models > 0,
        "meshModels": mesh_models,
        "voxelModels": voxel_models,
        "meshBytes": mesh_bytes,
        "voxelBytes": voxel_bytes,
        "meshTriangleBudget": int(mesh_budget),
        "meshOverBudget": over_budget,
    }


def build_3d(world_out: Path, grad_dir: Path | None, mesh_budget: int = DEFAULT_MESH_BUDGET) -> dict | None:
    """Build <world_out>/3d. Returns the terrain3d block for map.json, or None without a DEM."""
    dem = world_out / "dem" / "dem.asc.gz"
    if not dem.exists():
        dem = world_out / "dem" / "dem.asc"
    if not dem.exists():
        return None

    out_dir = world_out / "3d"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    grid, cellsize = _read_dem(dem)
    terrain = {"schema": SCHEMA, "heights": _write_heights(grid, cellsize, out_dir)}
    del grid

    chunks = terrain["heights"]["chunks"]
    objects = None
    if grad_dir is not None:
        objects = _write_objects(Path(grad_dir) / "3d", chunks["size"], chunks["countX"], chunks["countY"],
                                 out_dir, mesh_budget)
    if objects is not None:
        terrain["objects"] = objects

    (out_dir / "terrain.json").write_text(json.dumps(terrain), encoding="utf-8")
    return {
        "schema": SCHEMA,
        "path": "3d/terrain.json",
        "hasObjects": objects is not None,
        "hasVoxel": bool(objects and objects.get("hasVoxel")),
        "hasMesh": bool(objects and objects.get("hasMesh")),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("world_out", type=Path, help="processed world directory (contains dem/)")
    ap.add_argument("--grad-dir", type=Path, default=None, help="raw grad_meh directory (contains 3d/)")
    ap.add_argument("--mesh-budget", type=int, default=DEFAULT_MESH_BUDGET,
                    help="max triangles per model in the real-mesh stream (0 disables the limit)")
    args = ap.parse_args()
    block = build_3d(args.world_out, args.grad_dir, args.mesh_budget)
    if block is None:
        print("no DEM found; nothing built")
        return 1
    map_json = args.world_out / "map.json"
    if map_json.exists():
        data = json.loads(map_json.read_text(encoding="utf-8"))
        data["terrain3d"] = block
        map_json.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(json.dumps(block))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
