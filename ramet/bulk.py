"""Bulk-export loop control. Reads worlds.txt (in Arma3 root or RAMET/batch),
tracks which worlds have been processed in a small JSON state file so the
loop can resume across crashes/branch swaps.

API (called from SQF via Archangel):
    next_world()                     -> [str]   next pending world, or "" if exhausted
    mark_done(world, ok, err="")     -> [bool]  record completion (ok='true'/'false')
    log_progress(msg)                -> [bool]  append to ramet_bulk.log
"""

from __future__ import annotations

import datetime
import json
import threading
from pathlib import Path

_LOCK = threading.Lock()


def _arma_root() -> Path:
    return Path.cwd()


def _state_dir() -> Path:
    d = _arma_root() / "ramet_state"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _state_file() -> Path:
    return _state_dir() / "bulk_state.json"


def _log_file() -> Path:
    return _state_dir() / "ramet_bulk.log"


def _worlds_file() -> Path | None:
    # 1) Arma root
    p = _arma_root() / "worlds.txt"
    if p.exists():
        return p
    # 2) packaged batch/worlds.txt next to @root_amet
    for candidate in _arma_root().glob("@*/batch/worlds.txt"):
        return candidate
    # 3) RAMET project tree (dev runs)
    p = _arma_root().parent / "batch" / "worlds.txt"
    if p.exists():
        return p
    return None


def _load_state() -> dict:
    f = _state_file()
    if not f.exists():
        return {"queue": [], "done": {}, "loaded_from": None}
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except Exception:
        return {"queue": [], "done": {}, "loaded_from": None}


def _save_state(state: dict) -> None:
    _state_file().write_text(json.dumps(state, indent=2), encoding="utf-8")


def _ensure_queue(state: dict) -> dict:
    if state["queue"]:
        return state
    wf = _worlds_file()
    if wf is None:
        return state
    raw = wf.read_text(encoding="utf-8").splitlines()
    worlds = [ln.strip() for ln in raw if ln.strip() and not ln.strip().startswith("#")]
    state["queue"] = worlds
    state["loaded_from"] = str(wf)
    _save_state(state)
    return state


def next_world():
    with _LOCK:
        state = _ensure_queue(_load_state())
        for world in state["queue"]:
            if world.lower() not in {k.lower() for k in state.get("done", {}).keys()}:
                return [world]
        return [""]


def mark_done(world: str, ok: str = "true", err: str = ""):
    with _LOCK:
        state = _load_state()
        state.setdefault("done", {})[world] = {
            "ok": str(ok).lower() == "true",
            "err": err,
            "ts": datetime.datetime.utcnow().isoformat() + "Z",
        }
        _save_state(state)
        _append_log(f"mark_done {world} ok={ok} err={err!r}")
        return [True]


def _append_log(msg: str) -> None:
    line = f"[{datetime.datetime.utcnow().isoformat()}Z] {msg}\n"
    with _log_file().open("a", encoding="utf-8", errors="replace") as fp:
        fp.write(line)


def log_progress(msg: str):
    _append_log(msg)
    return [True]


def reset_state():
    """Manual recovery: delete state file. Callable from Python repl, not SQF."""
    f = _state_file()
    if f.exists():
        f.unlink()
    return [True]
