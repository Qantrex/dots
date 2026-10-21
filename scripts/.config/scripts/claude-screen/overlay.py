#!/usr/bin/env python3
# Faint answer overlay, bottom-right: a gtk-layer-shell surface on the overlay
# layer (above everything, fullscreen included), no keyboard focus and an empty
# input region so clicks go straight through. Text arrives on stdin.

import sys

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GLib, Gtk, GtkLayerShell, Pango  # noqa: E402

COLOR = (128, 128, 128)  # #808080
OPACITY = 0.06
FONT_SIZE = "12pt"
MARGIN = 24
MAX_WIDTH_CHARS = 70
MAX_CHARS = 2000
MIN_SECONDS = 20
WORDS_PER_SECOND = 3


def clear(_widget, cr):
    cr.set_source_rgba(0, 0, 0, 0)
    cr.set_operator(cairo.OPERATOR_SOURCE)
    cr.paint()
    cr.set_operator(cairo.OPERATOR_OVER)
    return False


def main():
    text = sys.stdin.read().strip()
    if not text:
        return 0

    win = Gtk.Window()
    win.set_visual(win.get_screen().get_rgba_visual())
    win.set_app_paintable(True)
    win.connect("draw", clear)
    win.connect("destroy", Gtk.main_quit)

    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "claude-screen")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)
    for edge in (GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.RIGHT):
        GtkLayerShell.set_anchor(win, edge, True)
        GtkLayerShell.set_margin(win, edge, MARGIN)

    r, g, b = COLOR
    css = Gtk.CssProvider()
    css.load_from_data(
        f"window {{ background-color: transparent; }}"
        f"label {{ color: rgba({r},{g},{b},{OPACITY}); font-size: {FONT_SIZE}; }}".encode()
    )
    Gtk.StyleContext.add_provider_for_screen(
        win.get_screen(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    if len(text) > MAX_CHARS:
        text = text[:MAX_CHARS].rstrip() + "…"

    label = Gtk.Label(label=text)
    label.set_line_wrap(True)
    label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
    # Without a width request, a wrapping label in a layer surface shrinks to
    # one word per line.
    longest = max(len(line) for line in text.splitlines())
    label.set_width_chars(min(MAX_WIDTH_CHARS, longest))
    label.set_max_width_chars(MAX_WIDTH_CHARS)
    label.set_xalign(0)
    win.add(label)

    win.show_all()
    win.input_shape_combine_region(cairo.Region())

    seconds = max(MIN_SECONDS, len(text.split()) // WORDS_PER_SECOND)
    GLib.timeout_add_seconds(seconds, Gtk.main_quit)
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
