--- @sync entry
-- Enter: step into a folder, open a file with its default app.
return {
	entry = function()
		local h = cx.active.current.hovered
		ya.emit(h and h.cha.is_dir and "enter" or "open", { hovered = true })
	end,
}
