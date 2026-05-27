"""Atomic stage-aware bulk-state storage (schema ramet-bulk-2).

State file lives at <Arma3>/ramet_state/bulk_state.json:

    {
      "schema": "ramet-bulk-2",
      "queue":  ["altis", "stratis", ...],
      "worlds": {
        "altis": {
          "grad_meh": { "done": true/false, "ok": true/false/null, "err": "...", "ts": "..." },
          "ocap":     { ... },
          "ingame":   { ... }
        }
      }
    }
"""
from __future__ import annotations

import datetime
import json
import os
import threading
from pathlib import Path
from typing import Iterable

SCHEMA = "ramet-bulk-2"
STAGES = ("grad_meh", "ocap", "ingame")

_LOCK = threading.Lock()


def _now_iso() -> str:
    return datetime.datetime.utcnow().isoformat() + "Z"


def _empty_cell() -> dict:
    return {"done": False, "ok": None, "err": "", "ts": None}


def _empty_world() -> dict:
    return {stage: _empty_cell() for stage in STAGES}


def _migrate_v1(raw: dict) -> dict:
    """v1 had {queue: [...], done: {<world>: {ok, err, ts}}}.
    Lossy: assume listed worlds completed grad_meh+ocap (the only stages v1 covered)."""
    queue = list(raw.get("queue", []) or [])
    worlds: dict[str, dict] = {}
    for w, info in (raw.get("done", {}) or {}).items():
        cell = _empty_cell()
        cell["done"] = True
        cell["ok"] = bool(info.get("ok", True))
        cell["err"] = info.get("err", "") or ""
        cell["ts"] = info.get("ts") or _now_iso()
        worlds[w] = {"grad_meh": dict(cell), "ocap": dict(cell), "ingame": _empty_cell()}
    return {"schema": SCHEMA, "queue": queue, "worlds": worlds, "migrated_from": "v1"}


def load(state_file: Path) -> dict:
    if not state_file.exists():
        return {"schema": SCHEMA, "queue": [], "worlds": {}}
    try:
        raw = json.loads(state_file.read_text(encoding="utf-8"))
    except Exception:
        return {"schema": SCHEMA, "queue": [], "worlds": {}}
    if raw.get("schema") == SCHEMA:
        # Sanity-fill any missing stages.
        for w, cells in (raw.get("worlds") or {}).items():
            for stage in STAGES:
                cells.setdefault(stage, _empty_cell())
        return raw
    if "done" in raw and isinstance(raw.get("done"), dict):
        print(f"[ramet.state] migrating bulk_state.json v1 -> {SCHEMA}")
        return _migrate_v1(raw)
    return {"schema": SCHEMA, "queue": raw.get("queue", []), "worlds": {}}


def save(state_file: Path, state: dict) -> None:
    tmp = state_file.with_suffix(state_file.suffix + ".tmp")
    tmp.write_text(json.dumps(state, indent=2), encoding="utf-8")
    os.replace(tmp, state_file)


def ensure_queue(state: dict, worlds: Iterable[str]) -> dict:
    if state.get("queue"):
        return state
    state["queue"] = list(worlds)
    for w in state["queue"]:
        state.setdefault("worlds", {}).setdefault(w, _empty_world())
    return state


def next_pending(state: dict, stage: str) -> str:
    if stage not in STAGES:
        return ""
    worlds = state.get("worlds", {})
    for w in state.get("queue", []):
        cell = worlds.get(w, _empty_world()).get(stage, _empty_cell())
        if not cell.get("done"):
            return w
    return ""


def mark_done(state: dict, stage: str, world: str, ok: bool, err: str = "") -> dict:
    if stage not in STAGES:
        return state
    worlds = state.setdefault("worlds", {})
    cells = worlds.setdefault(world, _empty_world())
    cells[stage] = {"done": True, "ok": bool(ok), "err": err or "", "ts": _now_iso()}
    return state


def stage_summary(state: dict, stage: str) -> tuple[int, int, list[str]]:
    """Returns (total_done, total_failed, failed_world_names)."""
    if stage not in STAGES:
        return (0, 0, [])
    done = 0
    failed: list[str] = []
    for w, cells in (state.get("worlds") or {}).items():
        cell = cells.get(stage, _empty_cell())
        if cell.get("done"):
            done += 1
            if not cell.get("ok"):
                failed.append(w)
    return (done, len(failed), failed)
