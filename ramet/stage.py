"""Move finished exporter outputs into RAMET/output/_intermediate/.
Keeps disk pressure bounded during a multi-world bulk run."""

from __future__ import annotations

import shutil
from pathlib import Path

from . import bulk


def _arma_root() -> Path:
    return Path.cwd()


def _intermediate_root() -> Path:
    # During in-game runs, RAMET lives next to Arma3. We dump into a sibling dir
    # the post-processing batch script knows about.
    target = _arma_root() / "ramet_intermediate"
    target.mkdir(parents=True, exist_ok=True)
    return target


def _move(src: Path, dst: Path) -> dict:
    if not src.exists():
        return {"moved": False, "reason": f"source missing: {src}"}
    if dst.exists():
        shutil.rmtree(dst, ignore_errors=True)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dst))
    return {"moved": True, "src": str(src), "dst": str(dst)}


def move_grad_meh(world: str):
    src = _arma_root() / "grad_meh" / world
    dst = _intermediate_root() / "grad_meh" / world
    result = _move(src, dst)
    bulk._append_log(f"stage.move_grad_meh {world}: {result}")
    return [result.get("moved", False), result.get("reason", "")]


def move_ocap(world: str):
    src = _arma_root() / "ocap_exporter" / world
    dst = _intermediate_root() / "ocap_rt" / world
    result = _move(src, dst)
    bulk._append_log(f"stage.move_ocap {world}: {result}")
    return [result.get("moved", False), result.get("reason", "")]
