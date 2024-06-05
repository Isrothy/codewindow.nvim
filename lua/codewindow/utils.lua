local M = {}

local get_line = vim.fn.line
local exe = vim.cmd.execute
local api = vim.api

---@param col integer The column number
---@param row integer The row number
---@return integer minimap_row The column in the minimap
---@return integer minimap_col The row in the minimap
function M.buf_to_minimap(col, row)
  local config = require("codewindow.config").get()
  local minimap_row = math.floor((col - 1) / config.width_multiplier / 2) + 1
  local minimap_col = math.floor((row - 1) / 4) + 1
  return minimap_row, minimap_col
end

local braille_chars = "⠀⠁⠂⠃⠄⠅⠆⠇⡀⡁⡂⡃⡄⡅⡆⡇⠈⠉⠊⠋⠌⠍⠎⠏⡈⡉⡊⡋⡌⡍⡎⡏"
  .. "⠐⠑⠒⠓⠔⠕⠖⠗⡐⡑⡒⡓⡔⡕⡖⡗⠘⠙⠚⠛⠜⠝⠞⠟⡘⡙⡚⡛⡜⡝⡞⡟"
  .. "⠠⠡⠢⠣⠤⠥⠦⠧⡠⡡⡢⡣⡤⡥⡦⡧⠨⠩⠪⠫⠬⠭⠮⠯⡨⡩⡪⡫⡬⡭⡮⡯"
  .. "⠰⠱⠲⠳⠴⠵⠶⠷⡰⡱⡲⡳⡴⡵⡶⡷⠸⠹⠺⠻⠼⠽⠾⠿⡸⡹⡺⡻⡼⡽⡾⡿"
  .. "⢀⢁⢂⢃⢄⢅⢆⢇⣀⣁⣂⣃⣄⣅⣆⣇⢈⢉⢊⢋⢌⢍⢎⢏⣈⣉⣊⣋⣌⣍⣎⣏"
  .. "⢐⢑⢒⢓⢔⢕⢖⢗⣐⣑⣒⣓⣔⣕⣖⣗⢘⢙⢚⢛⢜⢝⢞⢟⣘⣙⣚⣛⣜⣝⣞⣟"
  .. "⢠⢡⢢⢣⢤⢥⢦⢧⣠⣡⣢⣣⣤⣥⣦⣧⢨⢩⢪⢫⢬⢭⢮⢯⣨⣩⣪⣫⣬⣭⣮⣯"
  .. "⢰⢱⢲⢳⢴⢵⢶⢷⣰⣱⣲⣳⣴⣵⣶⣷⢸⢹⢺⢻⢼⢽⢾⢿⣸⣹⣺⣻⣼⣽⣾⣿"

---@param flag integer
---@return string
function M.flag_to_char(flag)
  return braille_chars:sub(flag * 3 + 1, (flag + 1) * 3)
end

--- The line number at the top of the window
---@param window integer?
---@return integer
function M.get_top_line(window)
  if window then
    return get_line("w0", window)
  end
  return get_line("w0")
end

--- The line number at the bottom of the window
---@param window integer?
---@return integer
function M.get_bot_line(window)
  if window then
    return get_line("w$", window)
  end
  return get_line("w$")
end

--- Scroll the window by the given amount
---@param winid integer
---@param amount integer
function M.scroll_window(winid, amount)
  if not api.nvim_win_is_valid(winid) then
    return
  end

  api.nvim_win_call(winid, function()
    if amount > 0 then
      local botline = M.get_bot_line(winid)
      local buffer = api.nvim_win_get_buf(winid)
      local height = api.nvim_buf_line_count(buffer)
      if botline >= height then
        return
      end
      local max_move_down = math.min(amount, height - botline)
      exe(string.format("\"normal! %d\\<C-e>\"", max_move_down))
    else
      amount = -amount
      local topline = M.get_top_line(winid)
      if topline <= 1 then
        return
      end
      local max_move_up = math.min(amount, topline - 1)
      exe(string.format("\"normal! %d\\<C-y>\"", max_move_up))
    end
  end)
end

return M
