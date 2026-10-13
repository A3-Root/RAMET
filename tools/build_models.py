"""Build the planner's map-independent 3D model library from modpack PBOs.

The terrain exporter only ever sees the models a world's WRP lists, so the
planner has no geometry for mission-placed content (vehicles, units, Zeus-placed
buildings from any mod) and draws bounding boxes instead. This driver runs the
native `ramet_models` tool over the modpack and assembles its output into the
single SQLite library the planner serves.

No Arma, no unpacking: the p3d reader opens PBOs directly.

    python tools/build_models.py --mod-root "<Arma3>/@77th_core" --out <dir>
    python tools/build_models.py --mod-root ... --out <dir> --update

`--update` only processes models that are new or whose PBO changed, which is the
cheap path after a modpack update. Normally driven by build_model_library.ps1.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

try:
    from model_category import categorise
except ImportError:  # running as tools.build_models
    from tools.model_category import categorise

SCHEMA = "ramet-models-1"

# Models handed to the native tool per child process. Bounding the batch means a
# panic inside the Rust p3d reader costs one restart, not the whole run.
BATCH_SIZE = 400

# Exit codes above this are abnormal terminations (an abort from a Rust panic
# shows up as a large unsigned status on Windows).
_CRASH_NOTE = "native tool terminated abnormally"


def _tool_candidates(repo: Path) -> list[Path]:
    name = "ramet_models.exe" if os.name == "nt" else "ramet_models"
    return [
        repo / "subprojects" / "grad_meh" / "build" / "lib64" / name,
        repo / "subprojects" / "grad_meh" / "install" / "bin" / name,
        repo / "tools" / name,
    ]


def find_tool(repo: Path, explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit)
        if not path.is_file():
            raise SystemExit(f"model tool not found: {path}")
        return path
    for candidate in _tool_candidates(repo):
        if candidate.is_file():
            return candidate
    looked = "\n  ".join(str(c) for c in _tool_candidates(repo))
    raise SystemExit(
        "ramet_models was not found. Build it with:\n"
        "  cmake --build --preset ninja-msvc-release --target ramet_models\n"
        f"Looked in:\n  {looked}"
    )


def read_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    if not path.is_file():
        return rows
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                # A torn last line is what a crash looks like; ignore it.
                continue
    return rows


def load_filter(path: Path) -> dict:
    if not path.is_file():
        return {"exclude": [], "minExtent": 1.0, "meshBudget": 20000, "voxelSize": 0.5}
    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    data.pop("_comment", None)
    return data


def run_scan(tool: Path, mod_roots: list[str], manifest: Path, excludes: list[str]) -> None:
    args = [str(tool), "scan"]
    for root in mod_roots:
        args += ["--mod-root", root]
    for needle in excludes:
        args += ["--exclude", needle]
    args += ["--out", str(manifest)]
    print(f"[scan] {len(mod_roots)} mod root(s)")
    result = subprocess.run(args, text=True, capture_output=True)
    for line in (result.stdout or "").splitlines():
        if line.strip():
            print(f"  {line}")
    if result.returncode != 0:
        sys.stderr.write(result.stderr or "")
        raise SystemExit(f"scan failed (exit {result.returncode})")


def pbo_stamp(path: str) -> str:
    """Identity of a PBO, so an updated mod rebuilds only what it changed."""
    try:
        info = os.stat(path)
    except OSError:
        return ""
    return f"{info.st_size}:{int(info.st_mtime)}"


def existing_rows(db: Path) -> dict[str, str]:
    """path -> source_stamp for every model already dealt with.

    Failures count as dealt with: a model skipped for being tiny or for being an
    unbinarised MLOD will be skipped again, so re-reading it on every update
    would mean re-reading most of the modpack. A changed PBO changes the stamp
    and the model is retried.
    """
    if not db.is_file():
        return {}
    known: dict[str, str] = {}
    with sqlite3.connect(db) as con:
        for table in ("models", "failures"):
            try:
                cur = con.execute(f"SELECT path, source_stamp FROM {table}")
            except sqlite3.OperationalError:
                continue
            for path, stamp in cur:
                if stamp:
                    known[path] = stamp
    return known


def write_jsonl(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row) + "\n")


def terminal_paths(attempts: Path) -> set[str]:
    """Paths the native tool has finished with, successfully or not."""
    states: dict[str, str] = {}
    for row in read_jsonl(attempts):
        path = row.get("path")
        state = row.get("state")
        if not path or not state:
            continue
        if state == "start":
            states.setdefault(path, "start")
        else:
            states[path] = state
    return {path for path, state in states.items() if state != "start"}


def run_build(tool: Path, staging: Path, options: dict, total: int) -> tuple[int, int]:
    """Runs the native tool until the staging manifest is drained.

    Returns (completed, restarts). A crash inside the p3d reader aborts the
    process, so the loop restarts it; the tool's own journal makes sure the
    offending model is quarantined rather than retried forever.
    """
    manifest = staging / "manifest.jsonl"
    attempts = staging / "library.attempts.jsonl"
    restarts = 0
    stalls = 0

    while True:
        done_before = len(terminal_paths(attempts))
        if done_before >= total:
            return done_before, restarts

        args = [
            str(tool), "build",
            "--manifest", str(manifest),
            "--library", str(staging),
            "--limit", str(BATCH_SIZE),
            "--voxel-size", str(options["voxelSize"]),
            "--mesh-budget", str(options["meshBudget"]),
            "--min-extent", str(options["minExtent"]),
        ]
        result = subprocess.run(args, text=True, capture_output=True)
        done_after = len(terminal_paths(attempts))

        if result.returncode != 0:
            restarts += 1
            print(f"  [restart {restarts}] {_CRASH_NOTE} (exit {result.returncode}) "
                  f"after {done_after}/{total}")

        if done_after == done_before:
            # No forward progress at all: the first unfinished model took the
            # process down before its journal entry could be written, or the
            # tool cannot run. Give up rather than spin.
            stalls += 1
            if stalls >= 3:
                print(f"  stalled at {done_after}/{total}; stopping")
                if result.stderr:
                    sys.stderr.write(result.stderr)
                return done_after, restarts
        else:
            stalls = 0
            print(f"  {done_after}/{total} models processed")


def assemble(db_path: Path, staging: Path, meta: dict, fresh: bool) -> dict:
    """Merge the native tool's bin+jsonl output into the SQLite library."""
    index = read_jsonl(staging / "library.jsonl")
    blob_path = staging / "library.bin"

    if fresh and db_path.is_file():
        db_path.unlink()

    con = sqlite3.connect(db_path)
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("""
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    """)
    con.execute("""
        CREATE TABLE IF NOT EXISTS models (
            path TEXT PRIMARY KEY,
            digest TEXT NOT NULL,
            category TEXT NOT NULL,
            map_type TEXT NOT NULL,
            bbox_min TEXT NOT NULL,
            bbox_max TEXT NOT NULL,
            voxel_size REAL NOT NULL,
            voxel_vertex_count INTEGER NOT NULL,
            voxel_index_count INTEGER NOT NULL,
            voxel_blob BLOB,
            mesh_vertex_count INTEGER NOT NULL,
            mesh_index_count INTEGER NOT NULL,
            mesh_decimated INTEGER NOT NULL,
            mesh_blob BLOB,
            source_pbo TEXT NOT NULL,
            source_stamp TEXT NOT NULL
        )
    """)
    con.execute("CREATE INDEX IF NOT EXISTS models_digest ON models(digest)")
    con.execute("""
        CREATE TABLE IF NOT EXISTS failures (
            path TEXT PRIMARY KEY,
            state TEXT NOT NULL,
            detail TEXT NOT NULL,
            source_pbo TEXT NOT NULL DEFAULT '',
            source_stamp TEXT NOT NULL DEFAULT ''
        )
    """)

    written = 0
    voxel_bytes = 0
    mesh_bytes = 0

    if index and blob_path.is_file():
        with blob_path.open("rb") as blob:
            for record in index:
                path = record.get("path") or ""
                if not path:
                    continue

                voxel = _read_stream(blob, record, "voxel")
                mesh = _read_stream(blob, record, "mesh")
                if not voxel and not mesh:
                    continue

                source_pbo = record.get("pbo", "")
                con.execute(
                    """
                    INSERT INTO models (path, digest, category, map_type, bbox_min, bbox_max,
                                        voxel_size, voxel_vertex_count, voxel_index_count, voxel_blob,
                                        mesh_vertex_count, mesh_index_count, mesh_decimated, mesh_blob,
                                        source_pbo, source_stamp)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    ON CONFLICT(path) DO UPDATE SET
                        digest=excluded.digest, category=excluded.category, map_type=excluded.map_type,
                        bbox_min=excluded.bbox_min, bbox_max=excluded.bbox_max,
                        voxel_size=excluded.voxel_size,
                        voxel_vertex_count=excluded.voxel_vertex_count,
                        voxel_index_count=excluded.voxel_index_count, voxel_blob=excluded.voxel_blob,
                        mesh_vertex_count=excluded.mesh_vertex_count,
                        mesh_index_count=excluded.mesh_index_count,
                        mesh_decimated=excluded.mesh_decimated, mesh_blob=excluded.mesh_blob,
                        source_pbo=excluded.source_pbo, source_stamp=excluded.source_stamp
                    """,
                    (
                        path,
                        hashlib.sha1(path.encode("utf-8")).hexdigest(),
                        categorise(record.get("mapType", ""), path),
                        record.get("mapType", ""),
                        json.dumps(record.get("bboxMin", [0, 0, 0])),
                        json.dumps(record.get("bboxMax", [0, 0, 0])),
                        float(record.get("voxelSize", 0.0) or 0.0),
                        int(record.get("voxelVertexCount", 0) or 0),
                        int(record.get("voxelIndexCount", 0) or 0),
                        voxel,
                        int(record.get("vertexCount", 0) or 0),
                        int(record.get("indexCount", 0) or 0),
                        1 if record.get("meshDecimated") else 0,
                        mesh,
                        source_pbo,
                        pbo_stamp(source_pbo),
                    ),
                )
                con.execute("DELETE FROM failures WHERE path = ?", (path,))
                written += 1
                voxel_bytes += len(voxel or b"")
                mesh_bytes += len(mesh or b"")

    # Where each model came from, so a failure can carry the same stamp a
    # success does and an update can skip it.
    sources = {row.get("path", ""): row.get("pbo", "")
               for row in read_jsonl(staging / "manifest.jsonl")}

    failed = 0
    for row in read_jsonl(staging / "library.attempts.jsonl"):
        state = row.get("state", "")
        path = row.get("path", "")
        if not path or state in {"start", "ok"}:
            continue
        source_pbo = sources.get(path, "")
        con.execute(
            "INSERT INTO failures (path, state, detail, source_pbo, source_stamp) VALUES (?,?,?,?,?) "
            "ON CONFLICT(path) DO UPDATE SET state=excluded.state, detail=excluded.detail, "
            "source_pbo=excluded.source_pbo, source_stamp=excluded.source_stamp",
            (path, state, row.get("detail", ""), source_pbo, pbo_stamp(source_pbo)),
        )
        failed += 1

    total = con.execute("SELECT COUNT(*) FROM models").fetchone()[0]
    for key, value in {
        "schema": SCHEMA,
        "builtAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "modelCount": str(total),
        # The cap, not a fixed size: the native tool scales each model's voxel
        # edge to its extent and clamps it to this.
        "voxelMaxSize": str(meta.get("voxelSize", "")),
        "meshTriangleBudget": str(meta.get("meshBudget", "")),
        "minExtent": str(meta.get("minExtent", "")),
        "modRoots": json.dumps(meta.get("modRoots", [])),
    }.items():
        con.execute(
            "INSERT INTO meta (key, value) VALUES (?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, value),
        )

    con.commit()
    con.execute("VACUUM")
    con.close()

    return {
        "written": written,
        "failed": failed,
        "total": total,
        "voxelBytes": voxel_bytes,
        "meshBytes": mesh_bytes,
    }


def _read_stream(blob, record: dict, kind: str) -> bytes | None:
    """Pull one model's vertex+index bytes out of the native tool's blob file.

    The two streams of a kind are written back to back, so a single read covers
    both and the planner can slice them with the counts.
    """
    if kind == "voxel":
        v_off = record.get("voxelVertexOffset")
        v_count = int(record.get("voxelVertexCount", 0) or 0)
        i_count = int(record.get("voxelIndexCount", 0) or 0)
    else:
        v_off = record.get("vertexOffset")
        v_count = int(record.get("vertexCount", 0) or 0)
        i_count = int(record.get("indexCount", 0) or 0)

    if v_off is None or (v_count == 0 and i_count == 0):
        return None
    size = v_count * 3 * 4 + i_count * 4
    if size <= 0:
        return None
    blob.seek(int(v_off))
    data = blob.read(size)
    return data if len(data) == size else None


def human(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024.0 or unit == "GB":
            return f"{value:.1f} {unit}"
        value /= 1024.0
    return f"{value:.1f} GB"


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Build the planner's 3D model library.")
    parser.add_argument("--mod-root", action="append", default=[], metavar="DIR",
                        help="modpack directory to scan; repeatable")
    parser.add_argument("--out", required=True, metavar="DIR",
                        help="output directory for library.sqlite")
    parser.add_argument("--filter", default=str(repo / "tools" / "model_filter.json"),
                        help="path filter and budgets (default: tools/model_filter.json)")
    parser.add_argument("--tool", default=None, help="path to ramet_models")
    parser.add_argument("--update", action="store_true",
                        help="only process models that are new or whose PBO changed")
    parser.add_argument("--keep-staging", action="store_true",
                        help="keep the intermediate bin/jsonl output for inspection")
    args = parser.parse_args()

    if not args.mod_root:
        parser.error("at least one --mod-root is required")

    tool = find_tool(repo, args.tool)
    config = load_filter(Path(args.filter))
    options = {
        "voxelSize": config.get("voxelSize", 0.5),
        "meshBudget": config.get("meshBudget", 20000),
        "minExtent": config.get("minExtent", 1.0),
        "modRoots": args.mod_root,
    }

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    db_path = out_dir / "library.sqlite"
    staging = out_dir / "staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    full_manifest = staging / "scan.jsonl"
    run_scan(tool, args.mod_root, full_manifest, config.get("exclude", []))
    candidates = read_jsonl(full_manifest)
    if not candidates:
        print("nothing to do: scan found no models")
        return 1

    known = existing_rows(db_path) if args.update else {}
    todo = []
    unchanged = 0
    for entry in candidates:
        path = entry.get("path", "")
        if not path:
            continue
        if args.update and path in known and known[path] == pbo_stamp(entry.get("pbo", "")):
            unchanged += 1
            continue
        todo.append(entry)

    print(f"[plan] {len(candidates)} candidates, {len(todo)} to process"
          + (f", {unchanged} unchanged" if args.update else ""))

    stats = {"written": 0, "failed": 0, "total": 0, "voxelBytes": 0, "meshBytes": 0}
    if todo:
        write_jsonl(staging / "manifest.jsonl", todo)
        print(f"[build] {len(todo)} models, {BATCH_SIZE} per child process")
        completed, restarts = run_build(tool, staging, options, len(todo))
        print(f"[build] {completed}/{len(todo)} processed, {restarts} restart(s)")
        stats = assemble(db_path, staging, options, fresh=not args.update)
    elif db_path.is_file():
        stats = assemble(db_path, staging, options, fresh=False)

    if not args.keep_staging:
        shutil.rmtree(staging, ignore_errors=True)

    db_size = db_path.stat().st_size if db_path.is_file() else 0
    print()
    print(f"library : {db_path}")
    print(f"models  : {stats['total']} total, {stats['written']} written this run")
    print(f"failures: {stats['failed']} recorded (see the failures table)")
    print(f"geometry: {human(stats['voxelBytes'])} voxel, {human(stats['meshBytes'])} mesh")
    print(f"size    : {human(db_size)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
