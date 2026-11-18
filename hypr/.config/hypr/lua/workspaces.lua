-- Per-monitor workspaces: every screen has its own 1–10 on SUPER+1..0, and
-- SUPER+N switches only the screen you're on (focus follows the mouse, so that's
-- the screen under the cursor). Built in Lua because the plugins that do this
-- (split-monitor-workspaces, hyprsplit) break on Hyprland updates.
--
-- Screens are counted left to right. Screen k (from 0) uses Hyprland workspaces
-- k*10+1 .. k*10+10: on the PC the main screen keeps 1–10 and the side screen
-- gets 11–20 (shown as 1–10). With one screen, as on the laptop, nothing changes.

local host = require("lua.host")

local M = {}

-- Enabled screens that aren't mirrors, left to right.
local function screens()
    local list = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m.enabled and not m.is_mirror then
            table.insert(list, m)
        end
    end
    table.sort(list, function(a, b) return a.x < b.x end)
    return list
end

-- Index (from 0) of a screen in that order.
local function index_of(monitor)
    if not monitor then return 0 end
    for i, m in ipairs(screens()) do
        if m.name == monitor.name then return i - 1 end
    end
    return 0
end

-- Hyprland workspace id for "workspace n on the screen I'm on".
function M.here(n)
    return index_of(hl.get_active_monitor()) * 10 + n
end

-- The screen next to the focused one in a direction ("left"/"right"), or nil.
local function neighbour(dir)
    local list = screens()
    local i = index_of(hl.get_active_monitor()) + 1
    local j = dir == "left" and i - 1 or i + 1
    return list[j]
end

-- SUPER+N / SUPER+SHIFT+N.
function M.go(n)
    hl.dispatch(hl.dsp.focus({ workspace = M.here(n) }))
end

function M.send(n)
    hl.dispatch(hl.dsp.window.move({ workspace = M.here(n) }))
end

-- SUPER+ALT+arrow: the focused window goes to whatever the screen on that side
-- shows right now, and focus goes with it.
function M.throw(dir)
    local target = neighbour(dir)
    if not target or not target.active_workspace then return end
    hl.dispatch(hl.dsp.window.move({ workspace = target.active_workspace.id }))
end

-- Where the side apps live. PC: the side screen's 1–3. Laptop: 8–10 as before.
if host.is_pc then
    M.chat, M.music, M.mail = 11, 12, 13
    -- The main Claude chat, docked on the side screen (`dock`); the side screen shows it by default.
    M.claude = 14
else
    M.chat, M.music, M.mail = 10, 9, 8
end

-- PC: keep each screen's workspaces on that screen, matched by model like in
-- monitors.lua, so they come back to the right place after a screen reconnects.
if host.is_pc then
    for i = 1, 10 do
        hl.workspace_rule({ workspace = tostring(i),      monitor = "desc:AOC Q27G2G4", default = i == 1 })
        hl.workspace_rule({ workspace = tostring(i + 10), monitor = "desc:AOC 27G2G8",  default = i + 10 == M.claude })
    end
end

return M
