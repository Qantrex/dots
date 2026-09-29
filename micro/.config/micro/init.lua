-- Enter in the filemanager tree opens the entry (the plugin only uses Tab).
-- Returning true stops the "|InsertNewline" fallback in bindings.json, which
-- would otherwise insert a newline into the file that was just opened.
function treeEnter(bp)
    if filemanager ~= nil and bp.Buf:GetName() == "filemanager" then
        filemanager.try_open_at_cursor()
        return true
    end
    return false
end
