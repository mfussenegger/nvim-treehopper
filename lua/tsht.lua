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

  ---@diagnostic disable-next-line: deprecated
  local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
  for _, client in ipairs(get_clients({ bufnr = bufnr })) do
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


---@param bufnr integer
---@param lang? string
---@return vim.treesitter.LanguageTree?
---@return string? error message
local function _get_parser(bufnr, lang)
  if vim.fn.has("nvim-0.11") == 1 then
    return vim.treesitter.get_parser(bufnr, lang, { error = false })
  end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if ok then
    return parser, nil
  end
  return nil, tostring(parser)
end


local function get_parser(bufnr)
  local has_lang, lang = pcall(function()
    return require("nvim-treesitter.parsers").ft_to_lang(vim.bo.filetype)
  end)
  local parser, err = _get_parser(bufnr, has_lang and lang or nil)
  if parser then
    return parser
  end
  if string.find(vim.bo.filetype, '%.') then
    for ft in string.gmatch(vim.bo.filetype, '([^.]+)') do
      local _
      parser, _ = _get_parser(bufnr, ft)
      if parser then
        return parser
      end
    end
  end
  error(err)
end


local function insert_parent_ranges(ranges, node)
  table.insert(ranges, { node:range() })
  local parent = node:parent()
  while parent do
    table.insert(ranges, { parent:range() })
    parent = parent:parent()
  end
end

local function get_node(opts)
  if vim.treesitter.get_node then
    return vim.treesitter.get_node(opts)
  end
  return vim.treesitter.get_node_at_pos(
    opts.bufnr, opts.pos[1], opts.pos[2], { ignore_injections = opts.ignore_injections }
  )
end

local function ts_parents_from_cursor(opts)
  local injection = opts and opts.ignore_injections == false or false
  local parser = get_parser(0)
  local lnum, col = unpack(api.nvim_win_get_cursor(0))

  local node_id, ranges = nil, {}

  -- assume parser injection
  if injection then
    local node = get_node({ bufnr = 0, pos = {lnum - 1, col}, ignore_injections = false })
    if node ~= nil then
      node_id = node:id()
      insert_parent_ranges(ranges, node)
    end
  end

  -- ignore parser injection
  local trees = parser:parse()
  if not trees then
    return ranges
  end
  local root = trees[1]:root()
  local cursor_node = root:descendant_for_range(lnum - 1, col, lnum - 1, col)
  if not cursor_node then
    return ranges
  end

  -- if assumed injection is absent, return current list of the nodes
  if injection and cursor_node:id() == node_id then
    return ranges
  end

  -- insert parent nodes of cursor_node
  insert_parent_ranges(ranges, cursor_node)
  return ranges
end


local function get_nodes(opts)
  local nodes
  if opts.source then
    return opts.source()
  else
    local ok
    ok, nodes = pcall(ts_parents_from_cursor, opts)
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


--- Visual selection on a node
---
---@param opts table|nil
--- - ignore_injections boolean|nil defaults to true
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
--- - ignore_injections boolean|nil defaults to true
function M.move(opts)
  coroutine.wrap(function() move(opts) end)()
end


return M
