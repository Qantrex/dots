-- Environment variables
-- https://wiki.hypr.land/configuring/core/environment-variables/

-- Cursor for Hyprland's own (hyprcursor) renderer.
-- NOTE: the old hyprlang config read `env = HYPRCURSOR_THEME,,rose-pine-hyprcursor`
-- -- the doubled comma made the value a literal ",rose-pine-hyprcursor", so the
-- theme never resolved and Hyprland silently fell back to XCursor.
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "24")

-- Cursor for XWayland and anything else that only speaks XCursor.
hl.env("XCURSOR_THEME", "BreezeX-RosePine-Linux")
hl.env("XCURSOR_SIZE", "24")

-- Qt applications follow the qt5ct theme.
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
