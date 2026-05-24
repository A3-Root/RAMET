import os
import subprocess
import threading
from pathlib import Path

_jobs = {}
_lock = threading.Lock()


def _result(status, **values):
    data = [["status", status]]
    for key, value in values.items():
        if key == "error" and not value:
            continue
        data.append([key, "" if value is None else str(value)])
    return data


def _mod_root():
    return Path(__file__).resolve().parents[1]


def _arma_root():
    return Path.cwd()


def _key(world_name):
    return str(world_name).lower()


def _log_file(arma_root, key):
    log_dir = arma_root / "ocap_renderterrain_logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir / f"{key}.log"


def _run_logged(command, cwd, log_file, check=True):
    with log_file.open("a", encoding="utf-8", errors="replace") as outfile:
        outfile.write(f"$ {' '.join(str(part) for part in command)}\n")
    result = subprocess.run(command, cwd=str(cwd), check=False)
    with log_file.open("a", encoding="utf-8", errors="replace") as outfile:
        outfile.write(f"Exit code: {result.returncode}\n")
    if check and result.returncode != 0:
        raise RuntimeError(
            f"Command failed with exit code {result.returncode}: "
            f"{' '.join(str(part) for part in command)}"
        )
    return result


def _run(world_name):
    key = _key(world_name)
    arma_root = _arma_root()
    mod_root = _mod_root()
    docker_context = mod_root / "ocap_renderterrain"
    input_dir = arma_root / "ocap_exporter"
    output_dir = arma_root / "ocap_renderterrain_output"
    temp_dir = arma_root / "ocap_renderterrain_temp"
    log_file = _log_file(arma_root, key)
    docker_memory = os.environ.get("OCAP_RENDER_DOCKER_MEMORY", "48g")

    try:
        log_file.write_text("", encoding="utf-8")
        input_dir.mkdir(parents=True, exist_ok=True)
        output_dir.mkdir(parents=True, exist_ok=True)
        temp_dir.mkdir(parents=True, exist_ok=True)
        if not docker_context.exists():
            raise RuntimeError(f"Docker context not found: {docker_context}")

        with _lock:
            _jobs[key] = {
                "status": "building",
                "error": "",
                "output": output_dir,
                "log": log_file,
            }
        _run_logged(
            ["docker", "build", "-t", "ocap-renderterrain:latest", str(docker_context)],
            cwd=mod_root,
            log_file=log_file,
        )
        _run_logged(
            ["docker", "rm", "-f", f"ocap-renderterrain-{key}"],
            cwd=mod_root,
            log_file=log_file,
            check=False,
        )

        with _lock:
            _jobs[key] = {
                "status": "running",
                "error": "",
                "output": output_dir,
                "log": log_file,
            }
        _run_logged(
            [
                "docker",
                "run",
                "--name",
                f"ocap-renderterrain-{key}",
                "--mount",
                f"type=bind,src={input_dir},target=/app/input",
                "--mount",
                f"type=bind,src={output_dir},target=/app/output",
                "--mount",
                f"type=bind,src={temp_dir},target=/app/temp",
                "--env",
                f"OCAP_RENDER_WORLDS={key}",
                "--env",
                "OCAP_RENDER_MAX_SIZE=32768",
                f"--memory={docker_memory}",
                "ocap-renderterrain:latest",
            ],
            cwd=mod_root,
            log_file=log_file,
        )

        with _lock:
            _jobs[key] = {
                "status": "done",
                "error": "",
                "output": output_dir / key,
                "log": log_file,
            }
    except Exception as exc:
        with _lock:
            _jobs[key] = {
                "status": "error",
                "error": f"{exc}; see {log_file}",
                "output": output_dir / key,
                "log": log_file,
            }


def process_world(world_name):
    key = _key(world_name)
    with _lock:
        current = _jobs.get(key)
        if current and current.get("status") in {"queued", "building", "running"}:
            return _result(current["status"], output=current.get("output", ""))
        _jobs[key] = {"status": "queued", "error": "", "output": ""}

    threading.Thread(target=_run, args=(key,), daemon=True).start()
    return _result("queued", output="")


def get_status(world_name):
    key = _key(world_name)
    with _lock:
        current = _jobs.get(key, {"status": "idle", "error": "", "output": ""})
        return _result(
            current.get("status", "idle"),
            error=current.get("error", ""),
            output=current.get("output", ""),
        )
