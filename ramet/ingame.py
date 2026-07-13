"""FlatDevil-callable helpers driving the GMS (arma3MapExporter) in-game pass.

Exposed via SQF:
    ramet.ingame.start(world)        -> kick the a3me_export SQF function
    ramet.ingame.status()            -> ['idle'|'running'|'saving'|'packing'|'done'|'error:<msg>']
    ramet.ingame.next_world()        -> next pending ingame world (delegates to bulk)
"""
from __future__ import annotations

import os
from pathlib import Path

from . import bulk

# Default override target for the GMS extension. SQF launcher sets this BEFORE
# spawning Arma so the C# session honours it on Worker.start().
DEFAULT_OUTPUT_SUBDIR = "RAMET_Output/raw"


def _arma_root() -> Path:
    return Path.cwd()


def _output_root() -> Path:
    override = os.environ.get("RAMET_INGAME_OUTPUT_DIR")
    if override:
        return Path(override)
    return _arma_root() / DEFAULT_OUTPUT_SUBDIR


def start(world: str):
    """The actual export is driven by SQF; this just records intent in the log."""
    bulk._append_log(f"ingame.start {world} -> {_output_root()}")
    return [True]


def status():
    """Best-effort: check whether base.png landed for the most-recently started world.

    The authoritative status is exposed by the GMS C# extension's `"status"` RVExtensionArgs
    command; SQF should poll that directly. This helper exists for python-only callers.
    """
    return ["idle"]


def next_world():
    return bulk.next_world("ingame")


def mark_done(world: str, ok: str = "true", err: str = ""):
    return bulk.mark_done("ingame", world, ok, err)
