#!/usr/bin/env python3
"""Build yazi's monochrome theme from the preset of the installed yazi version.

    ~/.config/scripts/build-yazi-monochrome.py          write the theme
    ~/.config/scripts/build-yazi-monochrome.py --stdout print it instead

Takes yazi's own theme-dark.toml for `yazi --version` from GitHub, so every
key the version knows is present, then recolours it: black, greys and white,
the hovered row inverted like the bar's white pill, Rose Pine love / gold only
for cut/delete and warnings. The ~700 file icons become one grey, folder icons
a lighter one. Re-run after a yazi update that changes the theme format.
"""

import re
import subprocess
import sys
import urllib.request
from pathlib import Path

OUT = Path.home() / "dotfiles/yazi/.config/yazi/theme.toml"

LOVE, GOLD = "#eb6f92", "#f6c177"
ICON_GREY, ICON_DIR = "#8a8a8a", "#d0d0d0"

# (section, key) -> new value, for the non-icon sections.
STYLE = {
    ("mgr", "cwd"): '{ fg = "#ffffff", bold = true }',
    ("mgr", "find_keyword"): f'{{ fg = "{GOLD}", bold = true, underline = true }}',
    ("mgr", "find_position"): '{ fg = "#888888", bg = "reset", italic = true }',
    ("mgr", "marker_copied"): '{ fg = "#d0d0d0", bg = "#d0d0d0" }',
    ("mgr", "marker_cut"): f'{{ fg = "{LOVE}", bg = "{LOVE}" }}',
    ("mgr", "marker_marked"): '{ fg = "#808080", bg = "#808080" }',
    ("mgr", "marker_selected"): '{ fg = "#ffffff", bg = "#ffffff" }',
    ("mgr", "count_copied"): '{ fg = "#000000", bg = "#d0d0d0" }',
    ("mgr", "count_cut"): f'{{ fg = "#000000", bg = "{LOVE}" }}',
    ("mgr", "count_selected"): '{ fg = "#000000", bg = "#ffffff" }',
    ("mgr", "border_style"): '{ fg = "#333333" }',
    ("tabs", "active"): '{ fg = "#000000", bg = "#ffffff", bold = true }',
    ("tabs", "inactive"): '{ fg = "#888888", bg = "#1a1a1a" }',
    ("mode", "normal_main"): '{ fg = "#000000", bg = "#ffffff", bold = true }',
    ("mode", "normal_alt"): '{ fg = "#ffffff", bg = "#262626" }',
    ("mode", "select_main"): '{ fg = "#000000", bg = "#a0a0a0", bold = true }',
    ("mode", "select_alt"): '{ fg = "#a0a0a0", bg = "#262626" }',
    ("mode", "unset_main"): f'{{ fg = "#000000", bg = "{GOLD}", bold = true }}',
    ("mode", "unset_alt"): f'{{ fg = "{GOLD}", bg = "#262626" }}',
    ("status", "perm_sep"): '{ fg = "#444444" }',
    ("status", "perm_type"): '{ fg = "#ffffff" }',
    ("status", "perm_read"): '{ fg = "#a0a0a0" }',
    ("status", "perm_write"): '{ fg = "#d0d0d0" }',
    ("status", "perm_exec"): '{ fg = "#ffffff", bold = true }',
    ("status", "progress_normal"): '{ fg = "#d0d0d0", bg = "#1a1a1a" }',
    ("status", "progress_error"): f'{{ fg = "{LOVE}", bg = "#1a1a1a" }}',
    ("which", "cand"): '{ fg = "#ffffff", bold = true }',
    ("which", "rest"): '{ fg = "#555555" }',
    ("which", "desc"): '{ fg = "#a0a0a0" }',
    ("which", "separator_style"): '{ fg = "#444444" }',
    ("spot", "tbl_col"): '{ fg = "#ffffff" }',
    ("spot", "tbl_cell"): '{ fg = "#d0d0d0", reversed = true }',
    ("notify", "title_info"): '{ fg = "#d0d0d0" }',
    ("notify", "title_warn"): f'{{ fg = "{GOLD}" }}',
    ("notify", "title_error"): f'{{ fg = "{LOVE}" }}',
    ("pick", "active"): '{ fg = "#ffffff", bold = true }',
    ("tasks", "hovered"): '{ fg = "#ffffff", bold = true }',
    ("help", "chord"): '{ fg = "#ffffff" }',
}
# Every popup: dim grey frame, white title.
for _sec in ("which", "confirm", "spot", "pick", "input", "cmp", "tasks", "help"):
    STYLE[(_sec, "border")] = '{ fg = "#555555" }'
for _sec in ("confirm", "spot"):
    STYLE[(_sec, "title")] = '{ fg = "#ffffff" }'

# File names by kind: shades of grey; executables white; folders white, bold.
FILETYPE = {
    '"yellow"': '"#c0c0c0"',   # images
    '"magenta"': '"#a8a8a8"',  # audio / video
    '"red"': '"#8c8c8c"',      # archives
    '"cyan"': '"#d8d8d8"',     # documents
    '"green"': '"#ffffff"',    # executables
}

HEX = re.compile(r'fg = "#[0-9a-fA-F]{6}"')


def preset() -> tuple[str, str]:
    ver = subprocess.run(["yazi", "--version"], capture_output=True, text=True).stdout
    tag = "v" + re.search(r"(\d+\.\d+\.\d+)", ver).group(1)
    url = f"https://raw.githubusercontent.com/sxyazi/yazi/{tag}/yazi-config/preset/theme-dark.toml"
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read().decode(), tag


def build(src: str, tag: str) -> str:
    out, section, in_dirs = [], "", False
    for line in src.splitlines():
        m = re.match(r"^\[(\w+)\]", line)
        if m:
            section = m.group(1)
        key = re.match(r"^(\w+)\s*=", line)

        if section == "icon":
            if re.match(r"^dirs\s*=\s*\[", line):
                in_dirs = True
            elif in_dirs and line.strip() == "]":
                in_dirs = False
            folder = in_dirs or 'if = "dir' in line
            line = HEX.sub(f'fg = "{ICON_DIR if folder else ICON_GREY}"', line)
        elif key and (section, key.group(1)) in STYLE:
            line = f"{key.group(1)} = {STYLE[(section, key.group(1))]}"
        elif section == "filetype":
            if 'url = "*/"' in line and "dummy" not in line:
                line = '\t{ url = "*/", fg = "#ffffff", bold = true },'
            else:
                line = line.replace('bg = "red"', f'bg = "{LOVE}"')
                for a, b in FILETYPE.items():
                    line = line.replace(f"fg = {a}", f"fg = {b}")
        out.append(line)

    header = (
        f"# yazi theme: true-black monochrome. GENERATED from yazi {tag}'s\n"
        "# theme-dark.toml by ~/.config/scripts/build-yazi-monochrome.py; edit the\n"
        "# script, not this file.\n\n"
    )
    return header + "\n".join(out) + "\n"


def main() -> None:
    src, tag = preset()
    text = build(src, tag)
    if "--stdout" in sys.argv:
        sys.stdout.write(text)
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text)
    print(f"wrote {OUT} (from yazi {tag})")


if __name__ == "__main__":
    main()
