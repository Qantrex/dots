#!/usr/bin/env python3
"""Build the true-black "Monochrome" GTK3 + GTK4 theme from stock Adwaita-dark.

Adwaita compiles every colour to a literal (no named-colour hooks worth
using), so this pulls the dark theme out of libgtk-3 / libgtk-4 and rewrites
each colour:

  * dark greys (surfaces)  -> #000000, borders -> visible greys, so the
    darker-than-background Adwaita borders don't vanish on black
  * blue (selection, focus, suggested buttons) -> neutral grey of similar weight
  * any other hue          -> grey, except error red and warning orange, which
    become Rosé Pine Moon love / gold

libadwaita apps ignore GTK themes; ~/.config/gtk-4.0/gtk.css covers those.

Re-run after a gtk3/gtk4 update:  ~/.config/scripts/build-gtk-monochrome.py
"""
import re
import subprocess
from pathlib import Path

THEME = Path.home() / "dotfiles/gtk/.local/share/themes/Monochrome"
SOURCES = {
    "gtk-3.0": ("/usr/lib/libgtk-3.so.0", "/org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css"),
    "gtk-4.0": ("/usr/lib/libgtk-4.so.1", "/org/gtk/libgtk/theme/Default/Default-dark.css"),
}

# Adwaita-dark grey (by luma) -> monochrome grey. Unlisted greys are kept.
GREYS = {
    0x35: 0x00,  # window background
    0x2D: 0x00,  # view / entry background
    0x30: 0x00,  # backdrop view
    0x23: 0x00,  # content view
    0x26: 0x00,  # headerbar gradient
    0x2B: 0x00,  # headerbar gradient
    0x2E: 0x0A,  # backdrop entry / trough
    0x28: 0x0A,  # notebook header
    0x31: 0x0A,  # menu backdrop, scrollbar trough
    0x32: 0x0A,  # disabled fill, button bottom edge
    0x37: 0x1A,  # button hover
    0x3C: 0x1F,  # hover gradients
    0x42: 0x1A,  # check / radio
    0x1E: 0x2A,  # pressed / checked button
    0x2A: 0x1F,  # backdrop checked button
    0x25: 0x14,  # disabled checked button
    0x1B: 0x2E,  # borders
    0x20: 0x26,  # backdrop borders
    0x07: 0x26,  # bottom edges, headerbar border
    0x11: 0x3A,  # switch knob border
    0x14: 0x33,  # checked headerbar button border
    0x40: 0x33,  # menu arrow border
    0x3A: 0x4A,  # switch knob
    0x44: 0x55,  # switch knob
}
SEMANTIC = {
    (0xCC, 0x00, 0x00): (0xEB, 0x6F, 0x92),  # error      -> love
    (0xF5, 0x79, 0x00): (0xF6, 0xC1, 0x77),  # warning    -> gold
}

# Keep the lock-in obvious: accents are grey, not blue.
EXTRA = """
/* ---- Monochrome additions ------------------------------------------- */
entry:focus, spinbutton:focus:not(.vertical) {
  border-color: #8a8a8a;
  box-shadow: inset 0 0 0 1px #8a8a8a;
}
*:selected, selection, row:selected, iconview:selected {
  color: #ffffff;
}
tooltip, tooltip.background {
  background-color: #0a0a0a;
  border: 1px solid #333333;
}
headerbar, .titlebar { box-shadow: none; }
"""


def luma(r, g, b):
    return round(0.2126 * r + 0.7152 * g + 0.0722 * b)


def remap(r, g, b):
    if (r, g, b) in SEMANTIC:
        return SEMANTIC[(r, g, b)]
    if max(r, g, b) - min(r, g, b) <= 3:  # already grey
        v = GREYS.get(luma(r, g, b), luma(r, g, b))
    else:  # coloured -> grey; blues sit around luma 0x4b, i.e. selection
        v = luma(r, g, b)
        v = v if v <= 0x10 else round(v * 0.7)
    return v, v, v


def hex_sub(m):
    h = m.group(1)
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % remap(r, g, b)


def rgb_sub(m):
    fn, args = m.group(1), [a.strip() for a in m.group(2).split(",")]
    rgb = tuple(int(float(a)) for a in args[:3])
    if rgb == (21, 83, 158) and len(args) == 4:  # GTK4 focus ring: keep it visible
        r = g = b = 0x8A
    else:
        r, g, b = remap(*rgb)
    return f"{fn}({', '.join([str(r), str(g), str(b)] + args[3:])})"


def build(lib, resource):
    css = subprocess.run(["gresource", "extract", lib, resource],
                         check=True, capture_output=True, text=True).stdout
    css = re.sub(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b", hex_sub, css)
    css = re.sub(r"\b(rgba?)\(([^()]*)\)", rgb_sub, css)
    # Adwaita's embossed text shadows look muddy on pure black.
    css = re.sub(r"text-shadow: 0 -1px rgba\(0, 0, 0, [0-9.]+\);", "text-shadow: none;", css)
    css = re.sub(r"-gtk-icon-shadow: 0 -1px rgba\(0, 0, 0, [0-9.]+\);", "-gtk-icon-shadow: none;", css)
    # Images (check marks, slider knobs, selection handles) stay in libgtk.
    assets = "resource://" + resource.rsplit("/", 1)[0] + "/assets/"
    css = css.replace('url("assets/', f'url("{assets}')

    header = ("/* Monochrome: generated from Adwaita-dark by "
              "~/.config/scripts/build-gtk-monochrome.py -- do not edit. */\n")
    return header + css + EXTRA


def main():
    for subdir, (lib, resource) in SOURCES.items():
        out = THEME / subdir / "gtk.css"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(build(lib, resource))
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
