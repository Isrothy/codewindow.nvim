local api = vim.api

local treesitter_namespace = api.nvim_create_namespace("codewindow.treesitter")
local screenbounds_namespace = api.nvim_create_namespace("codewindow.screenbounds")
local diagnostic_namespace = api.nvim_create_namespace("codewindow.diagnostic")
local git_namespace = api.nvim_create_namespace("codewindow.git")
local cursor_namespace = api.nvim_create_namespace("codewindow.cursor")

---@param buffer integer
local function clear_namespaces(buffer)
  api.nvim_buf_clear_namespace(buffer, treesitter_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, screenbounds_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, diagnostic_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, git_namespace, 0, -1)
end

return {
  treesitter = treesitter_namespace,
  screenbounds = screenbounds_namespace,
  diagnostic = diagnostic_namespace,
  git = git_namespace,
  cursor = cursor_namespace,
  clear = clear_namespaces,
}
