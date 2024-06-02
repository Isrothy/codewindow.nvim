local M = {}

---@class Codewindow.Config
---@field auto_enable boolean?
---@field exclude_filetypes (string[])?
---@field exclude_buftypes (string[])?
---@field max_lines number?
---@field max_minimap_height number?
---@field minimap_width number?
---@field use_lsp boolean?
---@field use_treesitter boolean?
---@field use_git boolean?
---@field width_multiplier number?
---@field z_index number?
---@field show_cursor boolean?
---@field screen_bounds Codewindow.ScreenBounds?
---@field window_border string?
---@field relative Codewindow.Relative?
---@field events (string[])?

---@type Codewindow.Config | fun():Codewindow.Config | nil
vim.g.codewindow = vim.g.codewindow

---@type Codewindow.Config | fun():Codewindow.Config | nil
vim.b.codewindow = vim.b.codewindow

return M
