"""Bulk-export loop control. Reads worlds.txt (from @root_amet/batch/),
tracks completion in <Arma3>/ramet_state/bulk_state.json (schema ramet-bulk-2,
per-stage cells: grad_meh / ocap / ingame) so each pass can independently
resume across crashes / Steam branch swaps.

API (called from SQF via FlatDevil):
    next_world(stage)                        -> [str]   next pending world for the named stage
    mark_done(stage, world, ok, err="")      -> [bool]  record per-stage completion
    log_progress(msg)                        -> [bool]  append to ramet_bulk.log
    export_summary(stage)                    -> [int, int, str]
"""

from __future__ import annotations

import datetime
import threading
from pathlib import Path

from . import state as _state

_LOCK = threading.Lock()


def _arma_root() -> Path:
    return Path.cwd()


def _mod_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _state_dir() -> Path:
    d = _arma_root() / "ramet_state"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _state_file() -> Path:
    return _state_dir() / "bulk_state.json"


def _log_file() -> Path:
    return _state_dir() / "ramet_bulk.log"


def _worlds_file() -> Path | None:
    p = _mod_root() / "batch" / "worlds.txt"
    return p if p.exists() else None


def _load_worlds() -> list[str]:
    wf = _worlds_file()
    if wf is None:
        return []
    raw = wf.read_text(encoding="utf-8").splitlines()
    return [ln.strip() for ln in raw if ln.strip() and not ln.strip().startswith("#")]


def _load() -> dict:
    s = _state.load(_state_file())
    s = _state.ensure_queue(s, _load_worlds())
    return s


def _save(s: dict) -> None:
    _state.save(_state_file(), s)


def _stage(name: str) -> str:
    name = (name or "").strip().lower()
    if name in ("", "grad", "gradmeh", "grad_meh"):
        return "grad_meh"
    if name in ("ocap",):
        return "ocap"
    if name in ("ingame", "in_game", "in-game", "gms", "a3me"):
        return "ingame"
    return name  # fall through; state.py rejects unknown


def next_world(stage: str = "grad_meh"):
    with _LOCK:
        s = _load()
        w = _state.next_pending(s, _stage(stage))
        _save(s)
        return [w]


def mark_done(stage: str, world: str, ok: bool | str = True, err: str = ""):
    done = ok if isinstance(ok, bool) else str(ok).strip().lower() == "true"
    with _LOCK:
        s = _load()
        _state.mark_done(s, _stage(stage), world, done, err)
        _save(s)
        _append_log(f"mark_done stage={stage} {world} ok={ok} err={err!r}")
        return [True]


def _append_log(msg: str) -> None:
    line = f"[{datetime.datetime.utcnow().isoformat()}Z] {msg}\n"
    with _log_file().open("a", encoding="utf-8", errors="replace") as fp:
        fp.write(line)


def log_progress(msg: str):
    _append_log(msg)
    return [True]


def export_summary(stage: str = "grad_meh"):
    with _LOCK:
        s = _load()
        total, failed, names = _state.stage_summary(s, _stage(stage))
        return [total, failed, ", ".join(names)]


def reset_state():
    f = _state_file()
    if f.exists():
        f.unlink()
    return [True]
