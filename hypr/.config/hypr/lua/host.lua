-- Which machine this is, for the few settings that differ between them.
-- The machines: bauarch (laptop, ASUS Vivobook) and bauarch-pc (desktop).
-- Everything else is shared. The list of differences is in the README ("Per-machine differences").

local function read_hostname()
    local file = io.open("/etc/hostname")
    if not file then return "" end
    local name = file:read("*l") or ""
    file:close()
    return name
end

local name = read_hostname()

local function exists(path)
    local file = io.open(path)
    if file then file:close() return true end
    return false
end

return {
    name   = name,
    is_pc  = name == "bauarch-pc",
    -- ~/.config/<dir>/<base>-<hostname>.<ext> if that file exists, else nil.
    file   = function(dir, base, ext)
        local path = os.getenv("HOME") .. "/.config/" .. dir .. "/" .. base .. "-" .. name .. "." .. ext
        return exists(path) and path or nil
    end,
}
