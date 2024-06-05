local M = {}

local utils = require("codewindow.utils")
local minimap_txt = require("codewindow.text")
local minimap_hl = require("codewindow.highlight")

---@class Window
---@field focused boolean
---@field parent_win integer
---@field window integer
---@field buffer integer

---@type Window?
local window = nil

local api = vim.api
local defer = vim.schedule

---@param winid integer window id of the window that the minimap is attached to
---@param mwinid integer window id of the minimap
local function center_minimap(winid, mwinid)
  local topline = utils.get_top_line(winid)
  local botline = utils.get_bot_line(winid)

  local difference = math.ceil((botline - topline) / 4)

  local top_y = math.floor(topline / 4)
  local bot_y = top_y + difference - 1

  local minimap_top = utils.get_top_line(mwinid)
  local minimap_bot = utils.get_bot_line(mwinid)

  local top_diff = top_y - minimap_top
  local bot_diff = minimap_bot - bot_y

  local diff = top_diff - bot_diff
  if math.abs(diff) <= 1 then
    return
  end
  if diff < 0 then
    diff = math.ceil(diff / 2)
  else
    diff = math.floor(diff / 2)
  end

  utils.scroll_window(mwinid, diff)
end

---@param winid integer
---@param mwinid integer
local function display_screen_bounds(winid, mwinid)
  local ok = window and pcall(minimap_hl.display_screen_bounds, winid, mwinid) or false
  if not ok then
    defer(function()
      minimap_txt.update_minimap(api.nvim_win_get_buf(winid), window)
      minimap_hl.display_screen_bounds(winid, mwinid)
    end)
  end
end

---@param winid integer
---@param mwinid integer
---@param amount integer
local function scroll_parent_window(winid, mwinid, amount)
  utils.scroll_window(winid, amount)
  center_minimap(winid, mwinid)

  display_screen_bounds(winid, mwinid)
end

local augroup

function M.close_minimap()
  if api.nvim_buf_is_valid(window.buffer) then
    api.nvim_buf_delete(window.buffer, { force = true })
  end
  if augroup then
    api.nvim_clear_autocmds({ group = augroup })
  end
  window = nil
end

---@param winid integer
local function get_window_config(winid)
  local minimap_height = vim.fn.winheight(winid)
  local config = require("codewindow.config").get()
  if config.max_minimap_height then
    minimap_height = math.min(minimap_height, config.max_minimap_height)
  end

  local relative = config.relative
  local is_relative = config.relative == "win"
  local win = is_relative and winid or nil
  local col = is_relative and api.nvim_win_get_width(winid) or vim.o.columns - 1
  local row = (not is_relative and vim.o.showtabline > 0) and 1 or 0

  local height = (function()
    local border = config.window_border
    if type(border) == "string" then
      return border == "none" and minimap_height or minimap_height - 2
    else
      local h = minimap_height
      if border[2] ~= "" then
        h = h - 1
      end
      if border[6] ~= "" then
        h = h - 1
      end
      return h
    end
  end)()

  return {
    relative = relative,
    win = win,
    anchor = "NE",
    width = config.minimap_width + 4,
    height = height,
    row = row,
    col = col,
    focusable = false,
    zindex = config.z_index,
    style = "minimal",
    border = config.window_border,
  }
end

---@param parent_buf integer
---@param on_switch_window function
---@param on_cursor_move function
local function setup_minimap_autocmds(parent_buf, on_switch_window, on_cursor_move)
  augroup = api.nvim_create_augroup("CodewindowAugroup", {})

  if not api.nvim_buf_is_valid(parent_buf or -1) then
    return
  end
  api.nvim_create_autocmd({ "WinScrolled" }, {
    buffer = parent_buf,
    callback = function()
      defer(function()
        center_minimap(window.parent_win, window.window)
        display_screen_bounds(window.parent_win, window.window)
        if api.nvim_win_is_valid(window.window) then
          api.nvim_win_set_config(window.window, get_window_config(window.parent_win))
        end
      end)
    end,
    group = augroup,
  })
  local config = require("codewindow.config").get()
  api.nvim_create_autocmd(config.events, {
    buffer = parent_buf,
    callback = function()
      defer(function()
        minimap_txt.update_minimap(api.nvim_win_get_buf(window.parent_win), window)
      end)
    end,
    group = augroup,
  })

  if not api.nvim_buf_is_valid(window.buffer or -1) then
    return
  end
  api.nvim_create_autocmd({ "BufWinLeave" }, {
    buffer = window.buffer,
    callback = function()
      defer(function()
        if not window then
          return
        end
        local new_buffer = api.nvim_get_current_buf()
        if api.nvim_win_is_valid(window.window) then
          api.nvim_win_set_buf(window.window, window.buffer)
        end
        if api.nvim_win_is_valid(window.parent_win) then
          api.nvim_win_set_buf(window.parent_win, new_buffer)
        end
        M.toggle_focused()
      end)
    end,
    group = augroup,
  })
  api.nvim_create_autocmd({ "WinClosed" }, {
    buffer = window.buffer,
    callback = function()
      if window == nil then
        return
      end
      M.close_minimap()
    end,
  })
  api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
    callback = function(args)
      if args.buf == window.buffer then
        return
      end
      on_switch_window()
    end,
    group = augroup,
  })

  api.nvim_create_autocmd({ "VimLeavePre", "SessionLoadPost" }, {
    callback = function()
      if window then
        M.close_minimap()
      end
    end,
  })

  -- only render when `show_cursor` is on
  if config.show_cursor then
    api.nvim_create_autocmd({ "CursorMoved" }, {
      buffer = window.buffer,
      callback = function()
        local topline = utils.get_top_line(window.parent_win)
        local botline = utils.get_bot_line(window.parent_win)
        local center = math.floor((topline + botline) / 2 / 4)
        local row = api.nvim_win_get_cursor(window.window)[1] - 1
        local diff = row - center
        scroll_parent_window(window.parent_win, window.window, diff * 4)
      end,
      group = augroup,
    })
    api.nvim_create_autocmd({ "CursorMoved" }, {
      callback = function()
        on_cursor_move()
      end,
      group = augroup,
    })
  end
end

---@param winid integer
---@return boolean
local function should_ignore(winid)
  local config = require("codewindow.config").get()
  local win_info = vim.fn.getwininfo(winid)
  local bufnr = win_info[1].bufnr

  ---@type string
  local buftype = api.nvim_get_option_value("buftype", { buf = bufnr })
  ---@type string
  local filetype = api.nvim_get_option_value("filetype", { buf = bufnr })

  if vim.tbl_contains(config.exclude_buftypes, buftype) then
    return true
  end
  if vim.tbl_contains(config.exclude_filetypes, filetype) then
    return true
  end
  if config.max_lines and api.nvim_buf_line_count(bufnr) > config.max_lines then
    return true
  end

  return false
end

---@param bufnr integer
---@param on_switch_window function
---@param on_cursor_move function
---@return Window?
function M.create_window(bufnr, on_switch_window, on_cursor_move)
  local current_window = api.nvim_get_current_win()

  if should_ignore(current_window) then
    if window == nil then
      return nil
    else
      if api.nvim_win_is_valid(window.parent_win) and api.nvim_win_is_valid(window.window) then
        api.nvim_win_set_config(window.window, get_window_config(window.parent_win))
        return nil
      else
        M.close_minimap()
      end
    end
  end

  if window and api.nvim_get_current_buf() == window.buffer then
    return nil
  end

  local window_height = vim.fn.winheight(current_window)
  if window_height <= 2 then
    return nil
  end

  if window then
    if api.nvim_win_is_valid(window.window) then
      api.nvim_win_set_config(window.window, get_window_config(current_window))
    end

    window.parent_win = current_window
    window.focused = false
  else
    local minimap_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_name(minimap_buf, "CodeWindow")
    api.nvim_set_option_value("filetype", "Codewindow", { buf = minimap_buf })

    local minimap_win = api.nvim_open_win(minimap_buf, false, get_window_config(current_window))

    api.nvim_set_option_value(
      "winhl",
      "Normal:CodewindowBackground,FloatBorder:CodewindowBorder",
      { win = minimap_win }
    )

    window = {
      buffer = minimap_buf,
      window = minimap_win,
      parent_win = api.nvim_get_current_win(),
      focused = false,
    }
  end

  if augroup then
    api.nvim_clear_autocmds({ group = augroup })
  end
  setup_minimap_autocmds(bufnr, on_switch_window, on_cursor_move)

  return window
end

---@param value boolean
function M.set_focused(value)
  if window == nil or window.focused == value then
    return
  end
  window.focused = value
  if window.focused then
    api.nvim_set_current_win(window.window)
  else
    api.nvim_set_current_win(window.parent_win)
  end
end

function M.toggle_focused()
  if window == nil then
    return
  end
  M.set_focused(not window.focused)
end

---@param amount integer
function M.scroll_minimap(amount)
  scroll_parent_window(window.parent_win, window.window, 4 * amount)
  utils.scroll_window(window.window, amount)
end

---@param amount integer
function M.scroll_minimap_by_page(amount)
  local window_height = api.nvim_win_get_height(window.parent_win)
  local actual_amount = math.floor(window_height * amount)
  actual_amount = actual_amount + (4 - actual_amount % 4) % 4
  scroll_parent_window(window.parent_win, window.window, actual_amount)
  utils.scroll_window(window.window, actual_amount / 4)
end

function M.scroll_minimap_top()
  scroll_parent_window(window.parent_win, window.window, -math.huge)
  utils.scroll_window(window.window, -math.huge)
end

function M.scroll_minimap_bot()
  scroll_parent_window(window.parent_win, window.window, math.huge)
  utils.scroll_window(window.window, math.huge)
end

function M.is_minimap_open()
  return window ~= nil
end

function M.get_minimap_window()
  return window
end

return M
