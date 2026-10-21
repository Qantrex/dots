#!/usr/bin/env python3
# SUPER+SHIFT+F: flameshot region -> question in wofi -> headless Claude Code
# session -> show_answer.py (JSON on stdin).

import fcntl
import json
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path.home() / ".cache" / "claude-screen"
DEFAULT_QUESTION = "Explain what is shown in this screenshot."
# Hyprland's exec environment may not have ~/.local/bin on PATH.
CLAUDE = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
TIMEOUT = 300


def notify(title, body=""):
    subprocess.run(["notify-send", "-a", "claude-screen", title, body])


def capture(path):
    shot = subprocess.run(["flameshot", "gui", "--raw"], capture_output=True)
    if shot.returncode != 0 or not shot.stdout:
        return False
    path.write_bytes(shot.stdout)
    return True


def ask_question():
    # Esc cancels; Enter on an empty box uses the default question.
    r = subprocess.run(
        ["wofi", "--dmenu", "--prompt", "Ask Claude about it (empty = explain)",
         "--cache-file", "/dev/null", "--lines", "1", "--width", "560"],
        input="", capture_output=True, text=True,
    )
    if r.returncode != 0:
        return None
    return r.stdout.strip() or DEFAULT_QUESTION


def run_claude(image, question):
    prompt = (
        f"{question}\n\n"
        f"The screenshot is the image file ./{image.name}. Read it with the Read tool, "
        "then answer concisely in plain text with no Markdown formatting."
    )
    r = subprocess.run(
        [CLAUDE, "-p", prompt,
         "--output-format", "json",
         "--tools", "Read",
         "--allowedTools", "Read",
         "--strict-mcp-config"],
        cwd=image.parent, capture_output=True, text=True, timeout=TIMEOUT,
    )
    try:
        out = json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"answer": r.stderr.strip() or r.stdout.strip() or "claude returned nothing",
                "session_id": None, "is_error": True}
    return {"answer": out.get("result", ""),
            "session_id": out.get("session_id"),
            "is_error": bool(out.get("is_error")) or r.returncode != 0}


def main():
    CACHE.mkdir(parents=True, exist_ok=True)

    lock = open(CACHE / ".lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        notify("Claude is still busy", "The previous screenshot is still being answered.")
        return 1

    image = CACHE / f"{datetime.now():%Y-%m-%d_%H-%M-%S}.png"
    if not capture(image):
        return 0

    question = ask_question()
    if question is None:
        image.unlink(missing_ok=True)
        return 0

    notify("Asking Claude…", question)
    try:
        result = run_claude(image, question)
    except subprocess.TimeoutExpired:
        result = {"answer": f"claude did not answer within {TIMEOUT}s",
                  "session_id": None, "is_error": True}

    payload = {"question": question, "image": str(image), **result}
    subprocess.run([sys.executable, str(HERE / "show_answer.py")],
                   input=json.dumps(payload), text=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
