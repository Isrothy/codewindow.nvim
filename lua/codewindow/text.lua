local M = {}

local minimap_hl = require("codewindow.highlight")
local minimap_diagnostics = require("codewindow.diagnostics")
local utils = require("codewindow.utils")

local api = vim.api

--- @param chr string
--- @return boolean
local function is_whitespace(chr)
  return chr == " " or chr == "\t" or chr == ""
end

--- @param col integer
--- @param row integer
--- @return integer
local function coord_to_flag(col, row)
  col = col - 1
  row = row - 1
  return math.pow(2, row % 4) * ((col % 2 == 0) and 1 or 16)
end

--- @param lines string[]
--- @return string[]
local function compress_text(lines)
  local config = require("codewindow.config").get()
  local scanned_text = {}
  for _ = 1, math.ceil(#lines / 4) do
    local line = {}
    for _ = 1, config.minimap_width do
      table.insert(line, 0)
    end
    table.insert(scanned_text, line)
  end

  for y = 1, #lines do
    local current_line = lines[y]
    for x = 1, config.minimap_width * 2 do
      local any_printable = false
      for dx = 1, config.width_multiplier do
        local actual_x = (x - 1) * config.width_multiplier + (dx - 1) + 1
        local chr = current_line:sub(actual_x, actual_x)
        if not is_whitespace(chr) then
          any_printable = true
        end
      end

      if any_printable then
        local flag = coord_to_flag(x, y)
        local chr_x = math.floor((x - 1) / 2) + 1
        local chr_y = math.floor((y - 1) / 4) + 1
        scanned_text[chr_y][chr_x] = scanned_text[chr_y][chr_x] + flag
      end
    end
  end

  ---@type string[]
  local minimap_text = {}
  for y = 1, #scanned_text do
    local line = ""
    for _, flag in ipairs(scanned_text[y]) do
      line = line .. utils.flag_to_char(flag)
    end
    table.insert(minimap_text, line)
  end

  return minimap_text
end

---@param current_buffer integer?
function M.update_minimap(current_buffer, window)
  if not current_buffer or not api.nvim_buf_is_valid(current_buffer) then
    return
  end
  local config = require("codewindow.config").get()

  api.nvim_set_option_value("modifiable", true, { buf = window.buffer })
  local lines = api.nvim_buf_get_lines(current_buffer, 0, -1, true)

  local minimap_text = compress_text(lines)

  local placeholder_str = string.rep(utils.flag_to_char(0), 2)

  local text = {}

  ---@type (string[])?
  local error_text
  if config.use_lsp then
    error_text = minimap_diagnostics.get_lsp_diagnostics(current_buffer)
  else
    error_text = {}
  end

  ---@type (string[])?
  local git_text
  if config.use_git then
    git_text = require("codewindow.git").parse_git_diff(lines)
  else
    git_text = {}
  end
  for i = 1, #minimap_text do
    local line = (error_text[i] or placeholder_str) .. minimap_text[i] .. (git_text[i] or placeholder_str)
    text[i] = line
  end

  api.nvim_buf_set_lines(window.buffer, 0, -1, true, text)

  if config.use_treesitter then
    local highlights = minimap_hl.extract_ts_highlights(current_buffer, lines)
    minimap_hl.apply_ts_highlights(highlights, window.buffer, lines)
  end

  if config.use_lsp then
    minimap_hl.apply_diagnostics_highlights(window.buffer, lines)
  end

  if config.use_git then
    minimap_hl.apply_git_highlights(window.buffer, lines)
  end

  if config.show_cursor then
    minimap_hl.display_cursor(window.parent_win, window.window)
  end

  minimap_hl.display_screen_bounds(window.parent_win, window.window)
  api.nvim_set_option_value("modifiable", false, { buf = window.buffer })
end

return M
