local M = {}

local diagnostic = vim.diagnostic

---@param buffer integer
---@return string[]
function M.get_lsp_diagnostics(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)
  local error_lines = {}
  for _ = 1, #lines do
    table.insert(error_lines, { warn = false, err = false })
  end

  local diagnostics = diagnostic.get(buffer, { severity = { min = diagnostic.severity.WARN } })
  for _, v in ipairs(diagnostics) do
    if v.severity == diagnostic.severity.WARN then
      if v.lnum + 1 <= #error_lines then
        error_lines[v.lnum + 1].warn = true
      end
    else
      if v.lnum + 1 <= #error_lines then
        error_lines[v.lnum + 1].err = true
      end
    end
  end

  local text = {}
  for i = 1, #error_lines + 3, 4 do
    local err_flag = 0
    local warn_flag = 0

    local flags = { 1, 2, 4, 8 }

    for di = 0, 3 do
      if error_lines[i + di] then
        if error_lines[i + di].err then
          err_flag = err_flag + flags[di + 1]
        end
        if error_lines[i + di].warn then
          warn_flag = warn_flag + flags[di + 1]
        end
      end
    end

    local utils = require("codewindow.utils")
    local err_char = utils.flag_to_char(err_flag)
    local warn_char = utils.flag_to_char(warn_flag)

    table.insert(text, err_char .. warn_char)
  end

  return text
end

return M
