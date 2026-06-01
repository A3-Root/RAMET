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


def peak_mb() -> int:
    """Peak (high-water-mark) RSS in MB for this process via VmHWM (Linux only)."""
    try:
        with open("/proc/self/status") as f:
            for line in f:
                if line.startswith("VmHWM:"):
                    return int(line.split()[1]) // 1024
    except Exception:
        pass
    return 0


def proc_rss_mb(pid: int) -> int:
    """RSS in MB of an arbitrary pid via /proc/<pid>/status. 0 if unavailable."""
    try:
        with open(f"/proc/{pid}/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) // 1024
    except Exception:
        pass
    return 0


def cgroup_mem_mb() -> tuple[int, int]:
    """(used_mb, limit_mb) for the container, best-effort.

    Tries cgroup v2 (memory.current / memory.max), then cgroup v1
    (memory.usage_in_bytes / limit_in_bytes), then /proc/meminfo as a host
    fallback. Returns (0, 0) if nothing is readable. limit_mb=0 means unlimited.
    """
    def _read_int(path: str) -> int | None:
        try:
            with open(path) as f:
                return int(f.read().strip())
        except Exception:
            return None

    # cgroup v2
    used = _read_int("/sys/fs/cgroup/memory.current")
    if used is not None:
        raw_max = None
        try:
            with open("/sys/fs/cgroup/memory.max") as f:
                txt = f.read().strip()
            raw_max = 0 if txt == "max" else int(txt)
        except Exception:
            raw_max = 0
        return used // (1024 * 1024), (raw_max // (1024 * 1024)) if raw_max else 0

    # cgroup v1
    used = _read_int("/sys/fs/cgroup/memory/memory.usage_in_bytes")
    if used is not None:
        lim = _read_int("/sys/fs/cgroup/memory/memory.limit_in_bytes") or 0
        # v1 reports a huge sentinel when unlimited
        if lim > (1 << 62):
            lim = 0
        return used // (1024 * 1024), (lim // (1024 * 1024)) if lim else 0

    # host fallback: /proc/meminfo (MemTotal - MemAvailable)
    try:
        info: dict[str, int] = {}
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    info[parts[0].rstrip(":")] = int(parts[1])  # kB
        total = info.get("MemTotal", 0)
        avail = info.get("MemAvailable", 0)
        return (total - avail) // 1024, total // 1024
    except Exception:
        return 0, 0


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
