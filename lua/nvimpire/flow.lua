-- ============================================================================
-- nvimpire/flow.lua
-- ----------------------------------------------------------------------------
-- The part a terminal genuinely cannot get from static highlight groups:
--   * per-character flowing gradients (Neovim extmarks), ported from the
--     VSCode theme's 8-color `.mtk1` default-text gradient;
--   * an animated caret that cycles the VSCode `div.cursor` rainbow gradient
--     on a timer.
--
-- Static syntax "gradient families" live in the groups/ files; this module
-- only adds dynamic, buffer-local decoration and is fully optional.
-- ============================================================================

local M = {}

local ns = vim.api.nvim_create_namespace('nvimpire_gradient_flow')

local uv = vim.uv or vim.loop

local state = {
  settings = nil,
  scope = 'comment',       -- comment | all | off
  flow_hls = {},           -- per-character highlight group names
  cursor_hls = {},         -- caret highlight group names
  cursor_timer = nil,
  cursor_index = 0,
  augroup = nil,
  redraw_timer = nil,
  colors = nil,
}

local MAX_COLS = 500       -- do not paint past this many columns on one line
local PAD_LINES = 40       -- paint a margin above/below the viewport

-- --------------------------------------------------------------------------
-- highlight groups for the ramps
-- --------------------------------------------------------------------------

local function build_ramp_hls(palette, prefix, extra)
  local names = {}
  for i, hex in ipairs(palette) do
    local name = string.format('%s%d', prefix, i)
    local attrs = { fg = hex }
    if extra then attrs = vim.tbl_extend('force', attrs, extra) end
    vim.api.nvim_set_hl(0, name, attrs)
    names[i] = name
  end
  return names
end

-- --------------------------------------------------------------------------
-- treesitter comment ranges (with a Vim-syntax fallback)
-- --------------------------------------------------------------------------

local function ts_comment_ranges(buf, top, bottom)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then return nil end

  local ranges = {}
  local trees = parser:parse()
  if not trees or not trees[1] then return ranges end

  local function walk(node)
    local nt = node:type()
    if nt == 'comment' or nt:find('comment') then
      local sr, sc, er, ec = node:range()
      if er >= top and sr <= bottom then
        ranges[#ranges + 1] = { sr, sc, er, ec }
      end
      return -- a comment node contains nothing else worth painting
    end
    for child in node:iter_children() do
      walk(child)
    end
  end

  for _, tree in ipairs(trees) do
    walk(tree:root())
  end
  return ranges
end

local function syntax_is_comment(buf, row, col)
  local stacks = vim.fn.synstack(row + 1, col + 1)
  for _, id in ipairs(stacks) do
    local name = vim.fn.synIDattr(id, 'name'):lower()
    if name:find('comment') then return true end
  end
  return false
end

-- --------------------------------------------------------------------------
-- painting
-- --------------------------------------------------------------------------

local function paint_char(buf, row, col, seq)
  local name = state.flow_hls[(seq % #state.flow_hls) + 1]
  vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
    end_col = col + 1,
    hl_group = name,
    priority = 210, -- above treesitter (~100)
    ephemeral = false,
  })
end

local function redraw_buf(buf)
  if not state.flow_hls or #state.flow_hls == 0 then return end
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  if vim.bo[buf].buftype ~= '' then return end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 0 then return end

  local top = math.max(0, vim.fn.line('w0', vim.api.nvim_get_current_win()) - 1 - PAD_LINES)
  local bottom = math.min(line_count - 1, vim.fn.line('w$', vim.api.nvim_get_current_win()) - 1 + PAD_LINES)

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local budget = 40000
  local scope = state.scope

  if scope == 'all' then
    for row = top, bottom do
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
      local limit = math.min(#line, MAX_COLS)
      for col = 0, limit - 1 do
        local byte = line:byte(col + 1)
        -- skip spaces and multi-byte continuation bytes
        if byte ~= 32 and byte >= 32 and budget > 0 then
          paint_char(buf, row, col, row * 7 + col)
          budget = budget - 1
        end
      end
    end
    return
  end

  -- scope == 'comment'
  local ranges = ts_comment_ranges(buf, top, bottom)
  if ranges then
    for _, r in ipairs(ranges) do
      local sr, sc, er, ec = r[1], r[2], r[3], r[4]
      local seq_base = sr * 7
      for row = sr, er do
        local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
        local c0 = (row == sr) and sc or 0
        local c1 = (row == er) and (ec - 1) or math.min(#line - 1, MAX_COLS - 1)
        for col = c0, c1 do
          if budget > 0 then
            paint_char(buf, row, col, seq_base + col)
            budget = budget - 1
          end
        end
      end
    end
  else
    -- fallback: Vim syntax clusters (slower, only the visible window)
    local vtop = vim.fn.line('w0') - 1
    local vbot = vim.fn.line('w$') - 1
    for row = vtop, vbot do
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
      for col = 0, math.min(#line - 1, MAX_COLS - 1) do
        if line:byte(col + 1) ~= 32 and syntax_is_comment(buf, row, col) and budget > 0 then
          paint_char(buf, row, col, row * 7 + col)
          budget = budget - 1
        end
      end
    end
  end
end

local function redraw_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 then redraw_buf(buf) end
    end
  end
end

local redraw_scheduled = false
local function schedule_redraw()
  if state.scope == 'off' or not state.settings or not state.settings.flow.enabled then
    return
  end
  if redraw_scheduled then return end
  redraw_scheduled = true
  vim.schedule(function()
    redraw_scheduled = false
    pcall(redraw_all)
  end)
end

-- --------------------------------------------------------------------------
-- flowing caret
-- --------------------------------------------------------------------------

local function stop_cursor()
  if state.cursor_timer then
    state.cursor_timer:stop()
    state.cursor_timer:close()
    state.cursor_timer = nil
  end
end

local function start_cursor()
  stop_cursor()
  if #state.cursor_hls == 0 then return end
  local c = state.colors
  state.cursor_index = 0
  state.cursor_timer = uv.new_timer()
  state.cursor_timer:start(0, 110, function()
    state.cursor_index = (state.cursor_index + 1) % #state.cursor_hls
    local hex = state.cursor_hls[state.cursor_index + 1]
    vim.schedule(function()
      for _, g in ipairs({ 'Cursor', 'lCursor', 'CursorIM', 'TermCursor' }) do
        vim.api.nvim_set_hl(0, g, { fg = c.bg_dark, bg = hex, bold = true })
      end
    end)
  end)
end

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

local function clear_flow()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
end

local function attach_autocmds()
  if state.augroup then return end
  state.augroup = vim.api.nvim_create_augroup('NvimpireGradientFlow', { clear = true })
  local events = {
    'TextChanged', 'TextChangedI', 'TextChangedP', 'WinScrolled',
    'BufEnter', 'InsertLeave', 'ColorScheme',
  }
  vim.api.nvim_create_autocmd(events, {
    group = state.augroup,
    callback = function(ev)
      if ev.event == 'ColorScheme' then return end
      schedule_redraw()
    end,
  })
end

local function detach_autocmds()
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
    state.augroup = nil
  end
end

--- (re)configure flow from resolved settings. Safe to call repeatedly.
function M.setup(settings, colors)
  state.settings = settings
  state.colors = colors

  -- ramp highlight groups
  state.flow_hls = build_ramp_hls(colors.text_flow, 'NvimpireFlow')
  state.cursor_hls = colors.cursor_flow

  state.scope = (settings.flow and settings.flow.scope) or 'comment'
  if not settings.flow or not settings.flow.enabled then
    state.scope = 'off'
  end

  -- per-character text gradient
  detach_autocmds()
  clear_flow()
  if settings.flow and settings.flow.enabled and state.scope ~= 'off' then
    attach_autocmds()
    schedule_redraw()
  end

  -- flowing caret
  stop_cursor()
  if settings.animated_cursor then
    start_cursor()
  end
end

function M.set_scope(scope)
  if not vim.tbl_contains({ 'comment', 'all', 'off' }, scope) then
    vim.notify('nvimpire: flow scope must be comment|all|off', vim.log.levels.ERROR)
    return
  end
  state.scope = scope
  clear_flow()
  if scope == 'off' then
    detach_autocmds()
  else
    attach_autocmds()
    redraw_all()
  end
end

function M.set_cursor(on)
  if on then start_cursor() else stop_cursor() end
end

function M.disable()
  stop_cursor()
  detach_autocmds()
  clear_flow()
end

return M
