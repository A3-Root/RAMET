"""Optional: kick off Docker post-processing while Arma exports the next world.
Non-blocking — returns immediately, log goes to ramet_state/ramet_bulk.log."""

from __future__ import annotations

import subprocess
import threading
from pathlib import Path

from . import bulk


def _arma_root() -> Path:
    return Path.cwd()


def _process_bat() -> Path | None:
    """Find the bundled ocap_renderterrain_process.bat (planted by hemtt bundle hook)."""
    candidates = [
        _arma_root() / "@ocap_renderterrain" / "ocap_renderterrain_process.bat",
        _arma_root() / "@root_amet" / "ocap_renderterrain_process.bat",
        _arma_root() / "ocap_renderterrain_process.bat",
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


def _spawn(world: str) -> None:
    bat = _process_bat()
    if bat is None:
        bulk._append_log(f"kickoff.run_docker {world}: process bat not found — skipped")
        return
    log_dir = _arma_root() / "ramet_state" / "kickoff_logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{world}.log"
    try:
        with log_path.open("a", encoding="utf-8", errors="replace") as fp:
            subprocess.Popen(
                [str(bat), world],
                cwd=str(bat.parent),
                stdout=fp,
                stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
            )
        bulk._append_log(f"kickoff.run_docker {world}: spawned -> {log_path}")
    except Exception as exc:
        bulk._append_log(f"kickoff.run_docker {world}: FAILED {exc!r}")


def run_docker(world: str):
    threading.Thread(target=_spawn, args=(world,), daemon=True).start()
    return [True]
