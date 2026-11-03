#!/usr/bin/env bash
# homerow typing test in its own foot window, like aerc: terminal font, palette
# and blur apply as usual. Already open: focus it.

bin="$HOME/.local/bin/homerow"

if hyprctl clients -j 2>/dev/null | grep -q '"class": "homerow"'; then
  exec hyprctl dispatch 'hl.dsp.focus({ window = "class:^(homerow)$" })' >/dev/null
fi

if [[ ! -x $bin ]]; then
  exec notify-send "homerow is not installed" "Build it: npm run deploy in ~/Projects/homerow"
fi

exec foot --app-id=homerow "$bin"
