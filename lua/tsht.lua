---@mod tsht Syntax trees + hop = treehopper

local api = vim.api
local M = {}
local ns = api.nvim_create_namespace('me.tsnode')

M.config = {hint_keys = {}}

local function keys_iter()
  local i = 0
  local len = #M.config.hint_keys
  return function()
    -- This won't work if there are too many nodes
    while true do
      i = i + 1
      if i <= len then
        return M.config.hint_keys[i]
      elseif (i - len) <= 26 then
        local c = string.char(i + 96)

        local k = true
        -- Skip already used hint_keys
        for _, v in ipairs(M.config.hint_keys) do
          if v == c then
            k = false
            break
          end
        end

        if k then return c end
      else
        local c = string.char(i + 65 - 27)

        local k = true
        -- Skip already used hint_keys
        for _, v in ipairs(M.config.hint_keys) do
          if v == c then
            k = false
            break
          end
        end

        if k then return c end
      end
    end
  end
end


local function co_resume(co)
  return function(err, response)
    coroutine.resume(co, err, response)
  end
end


local function lsp_selection_ranges()
  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  local line = api.nvim_get_current_line()
  local bufnr = api.nvim_get_current_buf()
  local co = coroutine.running()
  local nodes = {}
  local numSupported = 0
  for _, client in pairs(vim.lsp.get_active_clients({ bufnr = bufnr })) do
    if client.server_capabilities.selectionRangeProvider then
      numSupported = numSupported + 1
      local character = client.offset_encoding == 'utf-16' and vim.str_byteindex(line, col, true) or col
      local params = {
        textDocument = {
          uri = vim.uri_from_bufnr(bufnr)
        },
        positions = {
          { line = lnum - 1, character = character }
        }
      }
      local ok = client.request('textDocument/selectionRange', params, co_resume(co), bufnr)
      if ok then
        local err, response = coroutine.yield()
        assert(not err, vim.inspect(err))
        if response then
          local parent = response[1]
          while parent do
            local range = parent.range
            table.insert(nodes, {
              range.start.line,
              range.start.character,
              range['end'].line,
              range['end'].character
            })
            parent = parent.parent
          end
        end
      end
    end
  end
  assert(numSupported > 0, "No language servers support selectionRange")
  return nodes
end


local function get_parser(bufnr)
  local ts_parsers = require("nvim-treesitter.parsers")
  local lang = ts_parsers.ft_to_lang(vim.bo.filetype)

  local ok
  local parser
  if ts_parsers.has_parser(lang) then
    ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  else
    ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  end
  local err
  if ok then
    return parser
  else
    err = parser
  end
  if string.find(vim.bo.filetype, '%.') then
    for ft in string.gmatch(vim.bo.filetype, '([^.]+)') do
      ok, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
      if ok then
        return parser
      end
    end
  end
  error(err)
end


local function ts_parents_from_cursor()
  local parser = get_parser(0)
  local trees = parser:parse()
  local root = trees[1]:root()
  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  local cursor_node = root:descendant_for_range(lnum - 1, col, lnum - 1)
  local nodes = {{cursor_node:range()}}
  local parent = cursor_node:parent()
  while parent do
    local start_row, start_col, end_row, end_col = parent:range()
    table.insert(nodes, { start_row, start_col, end_row, end_col })
    parent = parent:parent()
  end
  return nodes
end


local function get_nodes(opts)
  local nodes
  if opts.source then
    return opts.source()
  else
    local ok
    ok, nodes = pcall(ts_parents_from_cursor)
    if ok then
      return nodes
    else
      return lsp_selection_ranges()
    end
  end
end


local function node_start(node)
  return { line = node[1], column = node[2] + 1, window = 0 }
end

local function node_end(node)
  return { line = node[3], column = node[4], window = 0 }
end


local function move(opts)
  local ok, hop = pcall(require, 'hop')
  if not ok then
    vim.notify('move requires the "hop" plugin', vim.log.levels.WARN)
    return
  end
  opts = opts or {}
  local nodes = get_nodes(opts)
  local transform = (opts.side or 'start') == 'start' and node_start or node_end
  local gen = function()
    return {
      jump_targets = vim.tbl_map(transform, nodes)
    }
  end
  hop.hint_with(gen)
end


local function region(opts)
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  opts = opts or {}
  local nodes = get_nodes(opts)
  local iter = keys_iter()
  local hints = {}
  local win_info = vim.fn.getwininfo(api.nvim_get_current_win())[1]
  for i = win_info.topline, win_info.botline do
    api.nvim_buf_add_highlight(0, ns, 'TSNodeUnmatched', i - 1, 0, -1)
  end
  for _, node in pairs(nodes) do
    local key = iter()
    local start_row = node[1]
    local start_col = node[2]
    local end_row = node[3]
    local end_col = node[4]
    api.nvim_buf_set_extmark(0, ns, start_row, start_col, {
      virt_text = {{key, 'TSNodeKey'}},
      virt_text_pos = 'overlay'
    })
    api.nvim_buf_set_extmark(0, ns, end_row, end_col, {
      virt_text = {{key, 'TSNodeKey'}},
      virt_text_pos = 'overlay'
    })
    hints[key] = node
  end
  vim.cmd('redraw')
  while true do
    local ok, keynum = pcall(vim.fn.getchar)
    if not ok then
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      break
    end
    if type(keynum) == "number" then
      local key = string.char(keynum)
      local node = hints[key]
      if node then
        local start_row, start_col, end_row, end_col = unpack(node)
        api.nvim_win_set_cursor(0, { start_row + 1, start_col })
        vim.cmd('normal! v')
        local max_row = api.nvim_buf_line_count(0)
        if max_row == end_row then
          end_row = end_row - 1
          end_col = #(api.nvim_buf_get_lines(0, end_row, end_row + 1, true)[1])
        elseif end_col == 0 then
          -- If the end points to the start of the next line, move it to the
          -- end of the previous line.
          -- Otherwise operations include the first character of the next line
          local end_line = api.nvim_buf_get_lines(0, end_row - 1, end_row, true)[1]
          end_row = end_row - 1
          end_col = #end_line
        end
        api.nvim_win_set_cursor(0, { end_row + 1, math.max(0, end_col - 1) })
        api.nvim_buf_clear_namespace(0, ns, 0, -1)
        break
      else
        vim.api.nvim_feedkeys(key, '', true)
        api.nvim_buf_clear_namespace(0, ns, 0, -1)
        break
      end
    end
  end
end


function M.nodes(opts)
  local run = coroutine.wrap(function()
    region(opts)
  end)
  run()
end


--- Move to the start or end of a node
--- This requires https://github.com/phaazon/hop.nvim
---
---@param opts table|nil
--- - side "start"|"end"|nil defaults to "start"
function M.move(opts)
  coroutine.wrap(function() move(opts) end)()
end


return M
