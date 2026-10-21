#!/usr/bin/env python3
# Receives Claude's answer from capture.py as JSON on stdin:
#   {"question", "image", "answer", "session_id", "is_error"}
# Saves it next to the screenshot, copies it, and opens it in a floating foot.

import json
import subprocess
import sys
from pathlib import Path


def notify(title, body="", urgency="normal"):
    subprocess.run(["notify-send", "-a", "claude-screen", "-u", urgency, title, body])


def main():
    data = json.load(sys.stdin)
    image = Path(data["image"])
    answer = data["answer"].strip()

    if data["is_error"]:
        notify("Claude failed", answer[:300], urgency="critical")
        return 1

    lines = [f"# {data['question']}", "", answer, "", "---", f"Screenshot: {image}"]
    if data["session_id"]:
        lines.append(f"Continue: cd {image.parent} && claude --resume {data['session_id']}")
    md = image.with_suffix(".md")
    md.write_text("\n".join(lines) + "\n")

    subprocess.run(["wl-copy"], input=answer, text=True)
    notify("Claude answered", "Copied to clipboard.")

    subprocess.Popen(["foot", "--app-id=claude-screen", "less", str(md)],
                     start_new_session=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
