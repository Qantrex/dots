-- Window and layer rules
-- https://wiki.hypr.land/configuring/core/rules/window-rules/
-- https://wiki.hypr.land/configuring/core/rules/layer-rules/
--
-- Rules are evaluated top to bottom; for a given effect, the LAST match wins.

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

-- Chat and music get their own workspaces.
--
-- The old rules matched `^(Vesktop)$` and `^(Spotify)$`. Both are
-- case-sensitive and the real classes are lowercase (`hyprctl clients` reports
-- `vesktop`), so neither rule ever fired. Matching both spellings fixes it.
hl.window_rule({
    name  = "chat-to-workspace-10",
    match = { class = "^([Vv]esktop|[Dd]iscord)$" },

    workspace = "10 silent",
})

hl.window_rule({
    name  = "music-to-workspace-9",
    match = { class = "^([Ss]potify)$" },

    workspace = "9 silent",
})

hl.window_rule({
    name  = "mail-to-workspace-8",
    match = { class = "^(aerc)$" },

    workspace = "8 silent",
})

-- The aerc cheatsheet (SUPER+H) tiles next to aerc, and takes you there.
hl.window_rule({
    name  = "mail-cheatsheet-to-workspace-8",
    match = { class = "^(aerc-cheat)$" },

    workspace = "8",
})

-- Whichever of aerc and its cheatsheet opens second, keep the sheet narrow and
-- on the right. Window rules cannot express a split ratio, so a script does it.
hl.on("window.open", function(win)
    if win.class == "aerc" or win.class == "aerc-cheat" then
        hl.exec_cmd("~/.config/scripts/aerc-cheatsheet.sh arrange " .. win.class)
    end
end)

-- Notifications (mako) get blurred, and see through to the wallpaper.
hl.layer_rule({
    name  = "blur-notifications",
    match = { namespace = "^notifications$" },

    blur         = true,
    ignore_alpha = 0.15,
    xray         = true,
})

-- The bar gets the same treatment.
hl.layer_rule({
    name  = "blur-bar",
    match = { namespace = "^waybar$" },

    blur         = true,
    ignore_alpha = 0.3,
})
