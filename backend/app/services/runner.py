import json
import subprocess
from pathlib import Path
from typing import Callable


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


def run_cmd_stream(
    command: list[str],
    cwd: Path | None = None,
    on_line: Callable[[str], None] | None = None,
) -> str:
    proc = subprocess.Popen(
        command,
        cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    lines: list[str] = []
    assert proc.stdout is not None
    for raw_line in proc.stdout:
        line = raw_line.rstrip("\n")
        lines.append(line)
        if on_line:
            on_line(line)
    proc.wait()
    output = "\n".join(lines)
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(command)}\nstdout={output}\nstderr=")
    return output
