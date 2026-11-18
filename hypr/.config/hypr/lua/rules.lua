-- Window and layer rules
-- https://wiki.hypr.land/configuring/core/rules/window-rules/
-- https://wiki.hypr.land/configuring/core/rules/layer-rules/
--
-- Rules are evaluated top to bottom; for a given effect, the LAST match wins.

local ws = require("lua.workspaces")

-- Ignore maximize requests from applications.
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Xwayland sometimes maps empty, borderless utility windows that steal focus
-- and break drags. Block the initial focus and ignore activation requests.
hl.window_rule({
    name  = "fix-xwayland-ghosts",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_initial_focus = true,
    suppress_event   = "activate activatefocus",
})

-- Chat, music and mail get their own workspaces: on the PC the side screen's 1–3,
-- on the laptop 10, 9 and 8 (lua/workspaces.lua).
--
-- The old rules matched `^(Vesktop)$` and `^(Spotify)$`. Both are
-- case-sensitive and the real classes are lowercase (`hyprctl clients` reports
-- `vesktop`), so neither rule ever fired. Matching both spellings fixes it.
hl.window_rule({
    name  = "chat-to-its-workspace",
    match = { class = "^([Vv]esktop|[Dd]iscord)$" },

    workspace = ws.chat .. " silent",
})

hl.window_rule({
    name  = "music-to-its-workspace",
    match = { class = "^([Ss]potify)$" },

    workspace = ws.music .. " silent",
})

hl.window_rule({
    name  = "mail-to-its-workspace",
    match = { class = "^(aerc)$" },

    workspace = ws.mail .. " silent",
})

-- Quick-ask Claude (SUPER+D, ~/.config/scripts/claude-ask.sh): floating and
-- centred on its own special workspace, so SUPER+D can hide it and bring it back.
hl.window_rule({
    name  = "claude-ask",
    match = { class = "^(claude-ask)$" },

    workspace = "special:ask silent",
    float     = true,
    size      = "900 600",
    center    = true,
})

-- The main Claude chat's side panel (SUPER+SHIFT+A, `dock` in ~/.local/bin): right edge, full height
-- below the bar, about 40 % wide, over whatever workspace you're on. The chat itself lives in tmux
-- window main:1 (`agentic`); the panel only shows it.
hl.window_rule({
    name  = "agentic-panel",
    match = { class = "^(agentic-panel)$" },

    workspace = "special:agentic silent",
    float     = true,
    size      = "monitor_w*0.4 monitor_h-68",
    move      = "monitor_w*0.6-15 53",
})

-- The aerc cheatsheet (SUPER+H) tiles next to aerc, and takes you there.
hl.window_rule({
    name  = "mail-cheatsheet-to-mail-workspace",
    match = { class = "^(aerc-cheat)$" },

    workspace = tostring(ws.mail),
})

-- Whichever of aerc and its cheatsheet opens second, keep the sheet narrow and
-- on the right. Window rules cannot express a split ratio, so a script does it.
hl.on("window.open", function(win)
    if win.class == "aerc" or win.class == "aerc-cheat" then
        hl.exec_cmd("~/.config/scripts/aerc-cheatsheet.sh arrange " .. win.class)
    end
end)

-- The shell's layers (Quickshell, namespaces qs-*) are blurred. Their
-- backgrounds are translucent black; ignore_alpha keeps the fully transparent
-- parts (around the bar's islands, the launcher's backdrop) unblurred.
hl.layer_rule({
    name  = "blur-shell",
    match = { namespace = "^qs-(bar|popout|notifications|osd)$" },

    blur         = true,
    ignore_alpha = 0.3,
})

-- The launcher dims the screen with a 0.35 black backdrop: only its box
-- (0.88) is blurred, not the whole screen.
hl.layer_rule({
    name  = "blur-launcher",
    match = { namespace = "^qs-launcher$" },

    blur         = true,
    ignore_alpha = 0.5,
})
