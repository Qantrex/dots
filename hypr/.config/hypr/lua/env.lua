-- Environment variables
-- https://wiki.hypr.land/configuring/core/environment-variables/

-- Cursor: Adwaita, plain black and white (the Rose Pine cursor had an iris/rose tint).
-- Adwaita has no hyprcursor version, so Hyprland and XWayland both use the XCursor
-- theme; ~/.icons/default and gsettings (autostart.lua) name the same one.
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")

-- Qt applications follow the qt5ct theme.
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

-- Editor for everything started from the session (aerc, git from GUI apps, sudoedit);
-- environment.d does not reach apps that Hyprland starts.
hl.env("EDITOR", "micro")
hl.env("VISUAL", "micro")
