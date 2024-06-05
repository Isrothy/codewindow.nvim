local M = {}

local defer = vim.schedule
local api = vim.api

function M.open_minimap()
  local minimap_txt = require("codewindow.text")
  local minimap_win = require("codewindow.window")
  local minimap_hl = require("codewindow.highlight")
  local current_buffer = api.nvim_get_current_buf()
  ---@type Window?
  local window
  window = minimap_win.create_window(current_buffer, function()
    defer(M.open_minimap)
  end, function()
    defer(function()
      local config = require("codewindow.config").get()
      if config.show_cursor then
        minimap_hl.display_cursor(window.parent_win, window.window)
      end
    end)
  end)

  if window == nil then
    return
  end

  minimap_txt.update_minimap(current_buffer, window)
end

function M.close_minimap()
  local minimap_win = require("codewindow.window")
  if minimap_win.is_minimap_open() then
    minimap_win.close_minimap()
  end
end

function M.toggle_focus()
  local minimap_win = require("codewindow.window")
  if minimap_win.is_minimap_open() then
    minimap_win.toggle_focused()
  end
end

function M.toggle_minimap()
  local minimap_win = require("codewindow.window")
  if minimap_win.is_minimap_open() then
    M.close_minimap()
  else
    M.open_minimap()
  end
end

function M.apply_default_keybinds()
  vim.keymap.set("n", "<leader>mo", M.open_minimap, { desc = "Open minimap" })
  vim.keymap.set("n", "<leader>mf", M.toggle_focus, { desc = "Toggle minimap focus" })
  vim.keymap.set("n", "<leader>mc", M.close_minimap, { desc = "Close minimap" })
  vim.keymap.set("n", "<leader>mm", M.toggle_minimap, { desc = "Toggle minimap" })
end

function M.setup()
  local minimap_hl = require("codewindow.highlight")
  minimap_hl.setup()

  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    callback = function()
      local config = require("codewindow.config").get()

      if not config.auto_enable then
        return
      end

      defer(M.open_minimap)
    end,
  })
end

return M
