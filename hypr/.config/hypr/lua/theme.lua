-- The current theme's values (colours, gaps, wallpaper, cursor, GTK names) for
-- look.lua, env.lua, apps.lua and autostart.lua.
--
-- ~/.config/hypr/theme.lua links to ~/dotfiles/theme/current/hypr.lua, which
-- `theme set <name>` renders from theme/templates/hypr.lua. dofile, not require,
-- so `hyprctl reload` after a switch always reads the new file. If it was never
-- rendered (a fresh clone), render it once here so the session still starts themed.

local path = os.getenv("HOME") .. "/.config/hypr/theme.lua"

local function load()
    local ok, t = pcall(dofile, path)
    if ok and type(t) == "table" then return t end
    return nil
end

local t = load()
if not t then
    os.execute(os.getenv("HOME") .. "/.local/bin/theme apply --quiet")
    t = load()
end
-- Still nothing: an empty table leaves Hyprland's own defaults in place.
return t or {}
