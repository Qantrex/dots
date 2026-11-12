#!/usr/bin/env python3
"""Writes data/emoji.tsv (emoji<TAB>name) for the launcher's emoji mode.

The system has no emoji list (no emoji-test.txt), so this uses Python's own
Unicode database: every single-codepoint emoji in the main emoji blocks, plus
the flags of the regional-indicator pairs that Noto Color Emoji draws.
Run it again after a Python update to pick up new emoji:
    python3 -I tools/gen-emoji.py
"""
import os
import unicodedata

RANGES = [
    (0x1F300, 0x1F5FF),  # symbols & pictographs
    (0x1F600, 0x1F64F),  # emoticons
    (0x1F680, 0x1F6FF),  # transport & map
    (0x1F900, 0x1F9FF),  # supplemental symbols & pictographs
    (0x1FA70, 0x1FAFF),  # symbols & pictographs extended-A
    (0x2600, 0x26FF),    # misc symbols
    (0x2700, 0x27BF),    # dingbats
]
# Text-default symbols need VS16 to render as emoji.
VS16 = "️"
FLAGS = ("AT DE CH IT FR ES GB US EU UA JP KR CN NL BE PL CZ HU SK SI HR SE NO DK FI "
         "PT GR TR IE CA AU NZ BR MX IN").split()

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "data", "emoji.tsv")
rows = []
for lo, hi in RANGES:
    for cp in range(lo, hi + 1):
        ch = chr(cp)
        name = unicodedata.name(ch, "")
        if not name or unicodedata.category(ch) not in ("So", "Sm"):
            continue
        if cp < 0x1F000:
            ch += VS16
        rows.append((ch, name.lower()))
for cc in FLAGS:
    flag = "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in cc)
    rows.append((flag, "flag " + cc.lower()))
with open(out, "w", encoding="utf-8") as f:
    for ch, name in rows:
        f.write(f"{ch}\t{name}\n")
print(f"{len(rows)} emoji -> {os.path.normpath(out)}")
