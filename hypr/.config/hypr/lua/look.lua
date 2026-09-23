-- Look and feel
-- https://wiki.hypr.land/configuring/core/config-options/

hl.config({
    general = {
        gaps_in  = 10,
        gaps_out = 15,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(848484aa)", "rgba(f9f9f9aa)" }, angle = 45 },
            -- Was rgba(000000aa): pure black, invisible against a dark
            -- wallpaper, so unfocused tiles had no discernible edge. A faint
            -- white keeps the layout readable without competing with the
            -- focused window's gradient and glow.
            inactive_border = "rgba(ffffff14)",
        },

        -- Resize windows by dragging borders/gaps.
        resize_on_border = false,

        -- See https://wiki.hypr.land/configuring/extra/tearing/ before enabling.
        allow_tearing = false,

        layout = "dwindle",

        -- Floating windows snap to each other and to monitor edges while dragging.
        snap = {
            enabled     = true,
            window_gap  = 10,
            monitor_gap = 10,
        },
    },

    decoration = {
        rounding       = 8,
        rounding_power = 2,

        active_opacity   = 0.95,
        inactive_opacity = 0.8,

        -- New in 0.56: a halo around the focused window. Kept white and faint
        -- so it reads as depth rather than colour, matching the monochrome bar.
        glow = {
            enabled        = true,
            range          = 12,
            render_power   = 2,
            color          = "rgba(ffffff28)",
            color_inactive = "rgba(00000000)",
        },

        -- Larger and softer than the old range = 4, which was tight enough to
        -- look like a border artifact rather than a shadow.
        shadow = {
            enabled        = true,
            range          = 20,
            render_power   = 3,
            color          = "rgba(000000aa)",
            color_inactive = "rgba(00000055)",
            offset         = { 0, 4 },
        },

        blur = {
            enabled            = true,
            size               = 7,
            passes             = 3,
            noise              = 0.015,
            contrast           = 1.0,
            brightness         = 0.9,
            vibrancy           = 0.17,
            popups             = true,
            popups_ignorealpha = 0.6,

            -- Blur the scratchpad too, so it matches everything else.
            special            = true,

            -- Cheaper blur for large static surfaces. Pure win at passes = 3.
            new_optimizations  = true,
        },

        -- Inactive windows already fade via inactive_opacity above; dimming as
        -- well double-darkens them. Uncomment to trade one for the other.
        -- dim_inactive = true,
        -- dim_strength = 0.1,
    },

    animations = {
        enabled = true,
    },

    -- https://wiki.hypr.land/configuring/layouts/dwindle-layout/
    dwindle = {
        preserve_split = true,
    },

    -- https://wiki.hypr.land/configuring/layouts/master-layout/
    master = {
        new_status = "master",
    },

    misc = {
        -- 0 disables the bundled anime mascot wallpapers.
        -- (-1 = pick one at random, 1 = force one. The old config's comment
        -- claimed "0 or 1 to disable", which was wrong about 1.)
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
    },
})

-- Curves, then the animations that use them.
-- https://wiki.hypr.land/configuring/core/animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- Sweep the border gradient once when focus lands on a window, and fade the
-- glow with it.
--
-- `style = "once"` matters on a laptop: "loop" rotates the gradient forever,
-- which keeps the GPU redrawing continuously and costs real battery. "once"
-- gives the same effect on focus change and then settles.
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "once" })
hl.animation({ leaf = "fadeGlow",    enabled = true, speed = 4,  bezier = "almostLinear" })

-- Special workspace (scratchpad) opens with no animation.
--
-- The old config said `animation = specialWorkspace, 0.1, 0.1, instant`, which
-- did not do what it looks like: the on/off field is an integer, so 0.1
-- truncated to 0 (disabled), and "instant" is not a defined curve so it fell
-- back to "default". Net effect was simply "off" -- kept here, but stated
-- honestly. For a fast slide instead, use:
--   hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 8, bezier = "easeOutQuint", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = false })

-- Workspace switching uses Hyprland's defaults. Uncomment to override:
-- hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
-- hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
-- hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- "Smart gaps" / "no gaps when only one window".
-- https://wiki.hypr.land/configuring/core/rules/workspace-rules/
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })
