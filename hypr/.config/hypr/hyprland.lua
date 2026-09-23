-- Hyprland configuration
-- https://wiki.hypr.land/configuring/core/
--
-- Lua config format, required since Hyprland 0.55 deprecated hyprlang.
-- The previous hyprlang config is kept in ./_backup-hyprlang-2026-09-23/.
--
-- Each `require` runs in its own scope, so an error in one module does not
-- stop the others from loading.

require("lua.monitors")
require("lua.env")
require("lua.look")
require("lua.input")
require("lua.keybinds")
require("lua.rules")
require("lua.permissions")

-- Last, so everything it depends on is configured before anything launches.
require("lua.autostart")
