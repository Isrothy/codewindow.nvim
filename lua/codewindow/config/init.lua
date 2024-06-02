local M = {}

---@return Codewindow.InternalConfig
M.get = function()
  ---@type Codewindow.Config
  local buffer_opt = type(vim.b.codewindow) == "function" and vim.b.codewindow()
    or vim.b.codewindow
    or {}

  ---@type Codewindow.Config
  local global_opt = type(vim.g.codewindow) == "function" and vim.g.codewindow()
    or vim.g.codewindow
    or {}

  ---@type Codewindow.Config
  local user_config = vim.tbl_deep_extend("force", global_opt, buffer_opt)

  ---@type Codewindow.InternalConfig
  local confg = vim.tbl_deep_extend("force", require("codewindow.config.internal").default_config, user_config)
  return confg
end

return M
