import json
import subprocess
from pathlib import Path


def run_cmd(command: list[str], cwd: Path | None = None) -> str:
    proc = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"Command failed: {' '.join(command)}\nstdout={proc.stdout}\nstderr={proc.stderr}"
        )
    return proc.stdout.strip()


def run_cmd_json(command: list[str], cwd: Path | None = None) -> dict:
    output = run_cmd(command, cwd=cwd)
    if not output:
        return {}
    return json.loads(output)
