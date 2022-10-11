local highlighter = require('vim.treesitter.highlighter')
local ts_utils    = require('nvim-treesitter.ts_utils')
local utils       = require('minimap.utils')
local M           = {}

local config = require('minimap.config').get_config()

local function most_commons(highlight) local count_table = {}

  for _, v in ipairs(highlight) do
    if not count_table[v] then
      count_table[v] = 0
    end
    count_table[v] = count_table[v] + 1
  end
  local max = 0
  for _, count in pairs(count_table) do
    if count > max then
      max = count
    end
  end

  local result = {}
  for entry, count in pairs(count_table) do
    if count == max then
      table.insert(result, entry)
    end
  end

  return result
end

function M.extract_highlighting(buffer, lines)
  local buf_highlighter = highlighter.active[buffer]

  local minimap_width = config.minimap_width
  local width_multiplier = config.width_multiplier

  local text_highlights = {}
  for _ = 1, #lines do
    local line = {}
    for _ = 1, minimap_width * width_multiplier * 2 do
      table.insert(line, "")
    end
    table.insert(text_highlights, line)
  end

  buf_highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()

    local query = buf_highlighter:get_query(tree:lang())

    if not query:query() then
      return
    end

    local iter = query:query():iter_captures(root, buf_highlighter.bufnr, 0, #lines + 1)

    for capture, node, _ in iter do
      local hl = query.hl_cache[capture]
      if hl then
        local c = query._query.captures[capture]
        if c ~= nil then
          local start_row, start_col, end_row, end_col = ts_utils.get_vim_range({ ts_utils.get_node_range(node) },
            buffer)

          for x = start_col, end_col do
            for y = start_row, end_row do
              if x <= #text_highlights[y] then
                text_highlights[y][x] = c
              end
            end
          end
        end
      end
    end
  end, true)

  local highlights = {}
  for _ = 1, math.floor(#lines / 4) + 1 do
    local line = {}
    for _ = 1, minimap_width do
      table.insert(line, {})
    end
    table.insert(highlights, line)
  end

  for y = 1, #text_highlights do
    for x = 1, #text_highlights[y] do
      if text_highlights[y][x] ~= '' then
        local minimap_x, minimap_y = utils.buf_to_minimap(x, y)

        table.insert(highlights[minimap_y][minimap_x], text_highlights[y][x])
      end
    end
  end

  for y = 1, #highlights do
    for x = 1, #highlights[y] do
      highlights[y][x] = most_commons(highlights[y][x])
    end
  end

  return highlights
end

function M.apply_highlight(highlights, buffer)
  local groups = require('nvim-treesitter.highlight').default_map;
  for y = 1, #highlights do
    for x = 1, #highlights[y] do
      for _, group in ipairs(highlights[y][x]) do
        local highlight_group = groups[group] or 'Normal';
        vim.highlight.range(buffer, 1, highlight_group, { y - 1, (x - 1) * 3 + 6 }, { y - 1, x * 3 + 6 }, {})
      end
    end
  end

  for y = 1, #highlights do
    vim.highlight.range(buffer, 3, "DiagnosticSignError", { y - 1, 0 }, { y - 1, 2 }, { inclusive = true })
    vim.highlight.range(buffer, 3, "DiagnosticSignWarn", { y - 1, 3 }, { y - 1, 5 }, { inclusive = true })
  end
end

function M.display_screen_bounds(window)
  vim.api.nvim_buf_clear_namespace(window.buffer, 2, 0, -1)

  local topline = vim.fn.line('w0')
  local botline = vim.fn.line('w$')

  local difference = math.ceil((botline - topline) / 4) + 1

  local top_y = math.floor(topline / 4)

  if top_y > 0 then
    vim.highlight.range(window.buffer, 2, "Underlined", { top_y - 1, 6 }, { top_y - 1, -1 }, {})
  end
  vim.highlight.range(window.buffer, 2, "Underlined", { top_y + difference, 6 }, { top_y + difference, -1 }, {})
end

return M
