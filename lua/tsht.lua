local api = vim.api
local M = {}
local ns = api.nvim_create_namespace('me.tsnode')


local function keys_iter()
  local i = 96
  return function()
    -- This won't work if there are too many nodes
    i = i + 1
    if i > 122 then
      i = 65
    end
    return string.char(i)
  end
end


function M.nodes()
  api.nvim_buf_clear_namespace(0, ns, 0, -1)
  local ts = vim.treesitter
  local get_query = require('vim.treesitter.query').get_query
  local query = get_query(vim.bo.filetype, 'locals')
  if not query then
    print('No locals query for language', vim.bo.filetype)
    return
  end
  local parser = ts.get_parser(0)
  local trees = parser:parse()
  local root = trees[1]:root()
  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  lnum = lnum - 1
  local cursor_node = root:descendant_for_range(lnum, col, lnum, col)
  local iter = keys_iter()
  local hints = {}
  local win_info = vim.fn.getwininfo(api.nvim_get_current_win())[1]
  for i = win_info.topline, win_info.botline do
    api.nvim_buf_add_highlight(0, ns, 'TSNodeUnmatched', i - 1, 0, -1)
  end
  local function register_node(node)
    local key = iter()
    local start_row, start_col, end_row, end_col = node:range()
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
  register_node(cursor_node)
  local parent = cursor_node:parent()
  while parent do
    register_node(parent)
    parent = parent:parent()
  end
  vim.cmd('redraw')
  local h = nil
  while h == nil do
    local ok, keynum = pcall(vim.fn.getchar)
    if not ok then
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      break
    end
    if type(keynum) == "number" then
      local key = string.char(keynum)
      local node = hints[key]
      if node then
        local start_row, start_col, end_row, end_col = node:range()
        api.nvim_win_set_cursor(0, { start_row + 1, start_col })
        vim.cmd('normal! v')
        api.nvim_win_set_cursor(0, { end_row + 1, end_col })
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


return M
