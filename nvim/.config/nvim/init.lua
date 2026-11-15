-- Monochrome nvim: the built-in "quiet" scheme on true black, in the desktop's greys.
-- Selection is inverse video; love and gold only for errors and warnings.
vim.o.termguicolors = true
vim.cmd.colorscheme("quiet")
vim.api.nvim_set_hl(0, "Normal",     { fg = "#e6e6e6", bg = "#000000" })
vim.api.nvim_set_hl(0, "Comment",    { fg = "#808080", italic = true })
vim.api.nvim_set_hl(0, "Visual",     { fg = "#000000", bg = "#ffffff" })
vim.api.nvim_set_hl(0, "ErrorMsg",   { fg = "#eb6f92" })
vim.api.nvim_set_hl(0, "WarningMsg", { fg = "#f6c177" })
