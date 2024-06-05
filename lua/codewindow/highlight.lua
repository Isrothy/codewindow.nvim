local M = {}

local api = vim.api
local highlight_range = vim.highlight.range

function M.setup()
  api.nvim_set_hl(0, "CodewindowBackground", { link = "Normal", default = true })
  api.nvim_set_hl(0, "CodewindowBorder", { fg = "#ffffff", default = true })
  api.nvim_set_hl(0, "CodewindowWarn", { link = "DiagnosticSignWarn", default = true })
  api.nvim_set_hl(0, "CodewindowError", { link = "DiagnosticSignError", default = true })
  api.nvim_set_hl(0, "CodewindowAddition", { fg = "#aadb56", default = true })
  api.nvim_set_hl(0, "CodewindowDeletion", { fg = "#fc4c4c", default = true })
  api.nvim_set_hl(0, "CodewindowUnderline", { underline = true, sp = "#ffffff", default = true })
  api.nvim_set_hl(0, "CodewindowBoundsBackground", { link = "CursorLine", default = true })
end

---The most common elements in the given table
---@generic T
---@param tbl table<T,integer>
---@return T[]
local function most_commons(tbl)
  local max = 0
  for _, count in pairs(tbl) do
    if count > max then
      max = count
    end
  end

  local result = {}
  for entry, count in pairs(tbl) do
    if count == max then
      table.insert(result, entry)
    end
  end

  return result
end

---Extracts the highlighting from the given buffer using treesitter.
---For any codepoint, the most common group will be chosen.
---If there are multiple groups with the same number of occurrences, all will be chosen.
---@param buffer integer
---@param lines string[]
---@return string[][][]?
M.extract_ts_highlights = function(buffer, lines)
  local config = require("codewindow.config").get()
  if not api.nvim_buf_is_valid(buffer) then
    return nil
  end

  local highlighter = require("vim.treesitter.highlighter")
  local buf_highlighter = highlighter.active[buffer]

  if buf_highlighter == nil then
    return nil
  end
  local line_count = #lines
  local minimap_width = config.minimap_width
  local minimap_height = math.ceil(line_count / 4)
  local width_multiplier = config.width_multiplier
  local minimap_char_width = minimap_width * width_multiplier * 2

  ---@type table<string,integer>[][]
  local highlights = {}
  for _ = 1, minimap_height do
    local line = {}
    for _ = 1, minimap_width do
      table.insert(line, {})
    end
    table.insert(highlights, line)
  end

  local ts_utils = require("nvim-treesitter.ts_utils")
  local utils = require("codewindow.utils")
  buf_highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()
    local lang = tree:lang()
    local query = vim.treesitter.query.get(lang, "highlights")
    if not query then
      return
    end

    local iter = query:iter_captures(root, buf_highlighter.bufnr, 0, line_count + 1)

    for capture_id, node in iter do
      local hl_group = query.captures[capture_id]
      local start_row, start_col, end_row, end_col =
        ts_utils.get_vim_range({ vim.treesitter.get_node_range(node) }, buffer)

      for y = start_row, end_row do
        for x = start_col, math.min(end_col, minimap_char_width) do
          local minimap_x, minimap_y = utils.buf_to_minimap(x, y)
          highlights[minimap_y][minimap_x][hl_group] = (highlights[minimap_y][minimap_x][hl_group] or 0) + 1
        end
      end
    end
  end)

  for y = 1, minimap_height do
    for x = 1, minimap_width do
      highlights[y][x] = most_commons(highlights[y][x])
    end
  end

  return highlights
end

---The index of an item in a list
---@param list any[]
---@param item any
---@return integer?
local function index_of(list, item)
  for i, v in ipairs(list) do
    if v == item then
      return i
    end
  end
  return nil
end

--- Applies the given highlights to the given buffer.
--- If there are multiple highlights for the same position, all of them will be applied.
---@param highlights string[][][]?
---@param buffer integer
---@param lines string[]
function M.apply_ts_highlights(highlights, buffer, lines)
  local config = require("codewindow.config").get()
  local namespaces = require("codewindow.namespace")
  local minimap_height = math.ceil(#lines / 4)
  local minimap_width = config.minimap_width

  api.nvim_buf_clear_namespace(buffer, namespaces.treesitter, 0, -1)
  api.nvim_buf_clear_namespace(buffer, namespaces.git, 0, -1)
  api.nvim_buf_clear_namespace(buffer, namespaces.diagnostic, 0, -1)
  if highlights ~= nil then
    for y = 1, minimap_height do
      for x = 1, minimap_width do
        for _, group in ipairs(highlights[y][x]) do
          if group ~= "" then
            -- For performance reasons, consecutive highlights are merged into one.
            local end_x = x
            while end_x < minimap_width do
              local pos = index_of(highlights[y][end_x + 1], group)
              if not pos then
                break
              end
              end_x = end_x + 1
              highlights[y][x][pos] = ""
            end
            api.nvim_buf_add_highlight(
              buffer,
              namespaces.treesitter,
              "@" .. group,
              y - 1,
              (x - 1) * 3 + 6,
              end_x * 3 + 6
            )
          end
        end
      end
    end
  end
end

---@param buffer integer
---@param lines string[]
function M.apply_diagnostics_highlights(buffer, lines)
  local diagnostic_namespace = require("codewindow.namespace").diagnostic
  api.nvim_buf_clear_namespace(buffer, diagnostic_namespace, 0, -1)
  local minimap_height = math.ceil(#lines / 4)
  for y = 1, minimap_height do
    api.nvim_buf_add_highlight(buffer, diagnostic_namespace, "CodewindowError", y - 1, 0, 3)
    api.nvim_buf_add_highlight(buffer, diagnostic_namespace, "CodewindowWarn", y - 1, 3, 6)
  end
end

---@param buffer integer
---@param lines string[]
function M.apply_git_highlights(buffer, lines)
  local config = require("codewindow.config").get()
  local git_namespace = require("codewindow.namespace").git
  api.nvim_buf_clear_namespace(buffer, git_namespace, 0, -1)
  local minimap_height = math.ceil(#lines / 4)
  local git_start = 6 + 3 * config.minimap_width
  for y = 1, minimap_height do
    highlight_range(buffer, git_namespace, "CodewindowAddition", { y - 1, git_start }, { y - 1, git_start + 3 }, {})
    highlight_range(buffer, git_namespace, "CodewindowDeletion", { y - 1, git_start + 3 }, { y - 1, git_start + 6 }, {})
  end
end

---@param winid integer
---@param mwinid integer
function M.display_screen_bounds(winid, mwinid)
  local bufnr = api.nvim_win_get_buf(mwinid)
  local config = require("codewindow.config").get()
  local screenbounds_namespaces = require("codewindow.namespace").screenbounds
  api.nvim_buf_clear_namespace(bufnr, screenbounds_namespaces, 0, -1)

  local utils = require("codewindow.utils")
  local topline = utils.get_top_line(winid)
  local botline = utils.get_bot_line(winid)

  local difference = math.ceil((botline - topline) / 4) + 1

  local top_y = math.floor(topline / 4)

  if top_y > 0 and config.screen_bounds == "lines" then
    api.nvim_buf_add_highlight(
      bufnr,
      screenbounds_namespaces,
      "CodewindowUnderline",
      top_y - 1,
      6,
      6 + config.minimap_width * 3
    )
  end

  local bot_y = top_y + difference - 1
  local buf_height = api.nvim_buf_line_count(bufnr)

  if bot_y > buf_height - 1 then
    bot_y = buf_height - 1
  end

  if bot_y < 0 then
    return
  end

  if config.screen_bounds == "lines" then
    api.nvim_buf_add_highlight(
      bufnr,
      screenbounds_namespaces,
      "CodewindowUnderline",
      bot_y,
      6,
      6 + config.minimap_width * 3
    )
  end

  if config.screen_bounds == "background" then
    for y = top_y, bot_y do
      api.nvim_buf_add_highlight(
        bufnr,
        screenbounds_namespaces,
        "CodewindowBoundsBackground",
        y,
        6,
        6 + config.minimap_width * 3
      )
    end
  end

  local center = math.floor((top_y + bot_y) / 2) + 1
  if api.nvim_win_is_valid(mwinid) then
    api.nvim_win_set_cursor(mwinid, { center, 0 })
  end
end

---@param winid integer
---@param mwinid integer
function M.display_cursor( winid, mwinid)
  local cursor_namespace = require("codewindow.namespace").cursor
  local bufnr = api.nvim_win_get_buf(mwinid)
  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, cursor_namespace, 0, -1)
  end
  if not api.nvim_win_is_valid(winid) then
    return
  end
  local cursor = api.nvim_win_get_cursor(winid)

  local utils = require("codewindow.utils")
  local minimap_x, minimap_y = utils.buf_to_minimap(cursor[2] + 1, cursor[1])

  minimap_x = minimap_x + 2 - 1
  minimap_y = minimap_y - 1

  if api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_add_highlight(bufnr, cursor_namespace, "Cursor", minimap_y, minimap_x * 3, minimap_x * 3 + 3)
  end
end

return M
