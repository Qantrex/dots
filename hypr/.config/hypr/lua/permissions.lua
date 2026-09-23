-- Permissions
-- https://wiki.hypr.land/configuring/core/advanced-configuration/permissions/
--
-- Changes here need a full Hyprland restart; they are deliberately not applied
-- on reload.
--
-- Left disabled, as in the previous config. Turning `enforce_permissions` on
-- without the allow rules below will make screenshots and screen sharing
-- prompt (or fail), so enable both together.

-- hl.config({
--     ecosystem = {
--         enforce_permissions = true,
--     },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
