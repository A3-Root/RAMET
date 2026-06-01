"""Shared timestamped logging utility for ramet-postprocess.

Each call writes a line to stdout AND to $RAMET_LOG_FILE (if set).
The log file path is set by orchestrate.py before spawning workers;
forked child processes inherit the env var automatically.
"""
from __future__ import annotations
import os
import time


def _mem_mb() -> int:
    """Current process RSS in MB via /proc/self/status (Linux only)."""
    try:
        with open("/proc/self/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) // 1024
    except Exception:
        pass
    return 0


def log(msg: str) -> None:
    """Print timestamped message to stdout and append to log file."""
    ts = time.strftime("%H:%M:%S")
    rss = _mem_mb()
    line = f"[{ts}] [rss={rss}MB] {msg}"
    print(line, flush=True)
    lf = os.environ.get("RAMET_LOG_FILE")
    if lf:
        try:
            with open(lf, "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except Exception:
            pass
