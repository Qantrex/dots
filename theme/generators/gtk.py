"""The GTK 3 + GTK 4 theme of a palette, built from the installed GTK's own Adwaita-dark.

`theme` calls build() on every switch; the result lands in theme/current/gtk/ and
GTK sees it as the theme "Current" (~/.local/share/themes/Current links there).

Adwaita compiles every colour to a literal (no named-colour hooks worth using), so
this pulls the dark theme out of libgtk-3 / libgtk-4 and rewrites each colour:

  * greys (surfaces, borders, text) -> tone(x) of the palette: in root the true-black
    greys below, so darker-than-background Adwaita borders don't vanish on black
  * blue (selection, focus, suggested buttons) -> a tone of similar weight
  * any other hue -> a tone too, except error red and warning orange, which become
    the palette's love / gold

libadwaita apps ignore GTK themes; templates/gtk4.css covers those. A GTK update
changes Adwaita: run `theme apply` afterwards.
"""
import re
import subprocess
from pathlib import Path

SOURCES = {
    "gtk-3.0": ("/usr/lib/libgtk-3.so.0", "/org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css"),
    "gtk-4.0": ("/usr/lib/libgtk-4.so.1", "/org/gtk/libgtk/theme/Default/Default-dark.css"),
}

# Adwaita-dark grey (by luma) -> tone level. Unlisted greys keep their level.
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
ERROR, WARNING = (0xCC, 0x00, 0x00), (0xF5, 0x79, 0x00)
FOCUS_RING = (21, 83, 158)  # GTK4's translucent focus ring: kept visible as tone 0x8a

# Keep the lock-in obvious: accents are tones, not blue.
EXTRA = """
/* ---- {name} additions ------------------------------------------- */
entry:focus, spinbutton:focus:not(.vertical) {{
  border-color: {focus};
  box-shadow: inset 0 0 0 1px {focus};
}}
*:selected, selection, row:selected, iconview:selected {{
  color: {fg};
}}
tooltip, tooltip.background {{
  background-color: {tooltip};
  border: 1px solid {border};
}}
headerbar, .titlebar {{ box-shadow: none; }}
"""

INDEX = """[Desktop Entry]
Type=X-GNOME-Metatheme
Name=Current
Comment=The {name} theme, generated from Adwaita-dark by ~/dotfiles/theme/generators/gtk.py

[X-GNOME-Metatheme]
GtkTheme=Current
IconTheme={icons}
"""


def luma(r, g, b):
    return round(0.2126 * r + 0.7152 * g + 0.0722 * b)


def build(ctx, out):
    tone = ctx["tone"]
    # [look] gtk_accent = true: Adwaita's blue (selection, focus, suggested buttons)
    # becomes the theme's accent at the same weight instead of a grey (nekosec: pink).
    accent = ctx["accent"] if getattr(ctx["look"], "gtk_accent", False) else None
    made = set()   # the accent shades handed out, to put on_accent text on them

    def remap(r, g, b):
        if (r, g, b) == ERROR:
            return ctx["love"]
        if (r, g, b) == WARNING:
            return ctx["gold"]
        if accent is not None and b > r + 40 and b > g + 20:  # a blue: the accent, as light or dark
            v = luma(r, g, b) / 0x4b
            c = accent.mix(ctx["bg"], min(0.8, max(0, 1 - v))) if v < 1 else accent.mix(ctx["fg"], min(0.7, v - 1))
            if c.luma > 110:   # light enough to carry text
                made.add(c.hex)
            return c
        if max(r, g, b) - min(r, g, b) <= 3:  # already grey
            v = GREYS.get(luma(r, g, b), luma(r, g, b))
        else:  # coloured; blues sit around luma 0x4b, i.e. selection
            v = luma(r, g, b)
            v = v if v <= 0x10 else round(v * 0.7)
        return tone(v)

    def hex_sub(m):
        h = m.group(1)
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        return "#" + remap(*(int(h[i:i + 2], 16) for i in (0, 2, 4))).hex

    def rgb_sub(m):
        fn, args = m.group(1), [a.strip() for a in m.group(2).split(",")]
        rgb = tuple(int(float(a)) for a in args[:3])
        c = tone(0x8A) if rgb == FOCUS_RING and len(args) == 4 else remap(*rgb)
        return f"{fn}({', '.join([str(c.r), str(c.g), str(c.b)] + args[3:])})"

    out = Path(out)
    for subdir, (lib, resource) in SOURCES.items():
        if not Path(lib).exists():  # gtk3 or gtk4 not installed (yet): skip that half
            print(f"theme: {lib} missing, no {subdir} theme until the next `theme apply`")
            continue
        css = subprocess.run(["gresource", "extract", lib, resource],
                             check=True, capture_output=True, text=True).stdout
        css = re.sub(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b", hex_sub, css)
        css = re.sub(r"\b(rgba?)\(([^()]*)\)", rgb_sub, css)
        # Adwaita also writes text and shadows as the names white and black. Left alone
        # they only match root; on a light theme the text would vanish on the background.
        css = re.sub(r"(?<=[\s:(,])(white|black)(?=[\s;,)])",
                     lambda m: str(remap(*((255,) * 3 if m.group(1) == "white" else (0,) * 3))), css)
        if accent is not None and made:
            # Light text on a light accent fill is unreadable: on_accent instead.
            shades = "|".join(made)
            on = "#" + ctx["on_accent"].hex

            def fix(m):
                body = m.group(2)
                if re.search(rf"background(-color)?:[^;]*#({shades})\b", body):
                    body = re.sub(r"(?<![-\w])color: #[0-9a-f]{6};",
                                  lambda c: f"color: {on};" if int(c.group(0)[8:10], 16) > 0xa0 else c.group(0), body)
                return m.group(1) + body + "}"
            css = re.sub(r"([^{}]*\{)([^{}]*)\}", fix, css)
        # Adwaita's embossed text shadows look muddy on a flat background.
        css = re.sub(r"text-shadow: 0 -1px rgba\(0, 0, 0, [0-9.]+\);", "text-shadow: none;", css)
        css = re.sub(r"-gtk-icon-shadow: 0 -1px rgba\(0, 0, 0, [0-9.]+\);", "-gtk-icon-shadow: none;", css)
        # Images (check marks, slider knobs, selection handles) stay in libgtk.
        assets = "resource://" + resource.rsplit("/", 1)[0] + "/assets/"
        css = css.replace('url("assets/', f'url("{assets}')

        header = (f"/* The {ctx['theme']} theme: generated from Adwaita-dark by "
                  "~/dotfiles/theme/generators/gtk.py -- do not edit. */\n")
        extra = EXTRA.format(name=ctx["theme"], focus=tone(0x8A), fg="currentColor" if accent is not None else ctx["fg"],
                             tooltip=tone(0x0A), border=tone(0x33))
        (out / subdir).mkdir(parents=True, exist_ok=True)
        (out / subdir / "gtk.css").write_text(header + css + extra)
    (out / "index.theme").write_text(INDEX.format(name=ctx["theme"], icons=ctx["asset"].icon_theme))
