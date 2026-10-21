#!/usr/bin/env python3
# SUPER+SHIFT+F: flameshot region -> headless Claude Code -> overlay.py (stdin).

import fcntl
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path.home() / ".cache" / "claude-screen"
PROMPT = (
    "Read the image ./shot.png with the Read tool. If it contains a question or "
    "problem, answer it; otherwise briefly explain what it shows. Reply concisely "
    "in plain text with no Markdown formatting."
)
# Hyprland's exec environment may not have ~/.local/bin on PATH.
CLAUDE = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
TIMEOUT = 300


def ask_claude(cwd):
    try:
        r = subprocess.run(
            [CLAUDE, "-p", PROMPT, "--output-format", "json",
             "--tools", "Read", "--allowedTools", "Read",
             "--strict-mcp-config", "--no-session-persistence"],
            cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return f"Claude did not answer within {TIMEOUT}s."
    try:
        return json.loads(r.stdout).get("result", "")
    except json.JSONDecodeError:
        return r.stderr.strip() or "Claude returned nothing."


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    lock = open(CACHE / ".lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0

    shot = subprocess.run(["flameshot", "gui", "--raw"], capture_output=True)
    if shot.returncode != 0 or not shot.stdout:
        return 0
    image = CACHE / "shot.png"
    image.write_bytes(shot.stdout)

    answer = ask_claude(CACHE)
    image.unlink(missing_ok=True)

    subprocess.run(["pkill", "-f", "claude-screen/overlay.py"])
    overlay = subprocess.Popen([sys.executable, str(HERE / "overlay.py")],
                               stdin=subprocess.PIPE, text=True, start_new_session=True)
    overlay.stdin.write(answer)
    overlay.stdin.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
