#!/bin/bash

# A simple script to use wofi as a clipboard history manager with cliphist.
# This script lists your clipboard history, lets you select an item with wofi,
# and then copies that item back to your clipboard.

# --- Requirements ---
# Make sure you have the following programs installed and in your PATH:
# 1. wofi
# 2. cliphist
# 3. wl-copy (part of wl-clipboard)
# 4. fnott

# List the clipboard history and pipe it to wofi in dmenu mode.
# We store the selected item in a variable so we can check if it's empty.
selection=$(cliphist list | wofi --dmenu --prompt="Cliphist Helper: ")

# Check if a selection was made.
if [ -n "$selection" ]; then
    # The selected item is then piped back to `cliphist decode` to get the raw text.
    # The `wl-copy` command then places the decoded text on the clipboard.
    echo "$selection" | cliphist decode | wl-copy

    # Use fnott to display a graphical notification.
    # The -m flag specifies the message body.
    # The -t flag specifies the title.
    # The -i flag specifies the icon.
    notify-send "Clipboard" "Item copied to clipboard."
fi
