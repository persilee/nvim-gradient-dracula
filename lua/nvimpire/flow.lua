-- ============================================================================
-- nvimpire/flow.lua
-- ----------------------------------------------------------------------------
-- INTRA-WORD gradient: the signature effect of the VSCode gradient-theme.
--
-- A colored WORD itself flows from the deep stop at its first letter to the
-- bright stop at its last letter (e.g. the keyword `colorscheme` is dark pink
-- at "c" and light pink at "e"). A terminal highlight group is one flat color,
-- so we walk every treesitter capture in the visible range, and place one
-- extmark PER LETTER, interpolating that capture's family gradient by the
-- letter's position inside the word.
--
--   treesitter capture  -> gradient family (deep -> bright)
--   keyword* / operator  -> keyword (pink)
--   function*/method     -> func    (green)
--   string*/character    -> string  (yellow)
--   type*/class         -> type    (cyan)
--   number/constant/bool -> constant(purple)
--   *parameter           -> parameter(orange)
--   tag / tag.attribute  -> tag / attr
--
-- Plain variables / punctuation are left at their normal color, so only the
-- colored words gradient-flow. A Vim-syntax fallback is used when no
-- treesitter parser/highlights query is available for the buffer.
-- ============================================================================

local grad = require('nvimpire.gradient')

local M = {}

local ns = vim.api.nvim_create_namespace('nvimpire_word_gradient')
local uv = vim.uv or vim.loop

local state = {
  settings = nil,
  colors = nil,
  enabled = true,
  comments = false,
  bold = true,
  augroup = nil,
  cursor_timer = nil,
  cursor_index = 0,
  cursor_saved = nil,
  hl_cache = {},
}

local PAD_LINES = 40
local MAX_COLS = 600
local CURSOR_GROUPS = { 'Cursor', 'lCursor', 'CursorIM', 'TermCursor' }

-- --------------------------------------------------------------------------
-- per-hex highlight groups (cached, reused across buffers / redraws)
-- --------------------------------------------------------------------------

local function hl_for_hex(hex)
  local name = state.hl_cache[hex]
  if not name then
    name = 'NvWord' .. hex:gsub('#', '')
    -- gradient words are bold (the VSCode theme renders gradient tokens at 700)
    vim.api.nvim_set_hl(0, name, { fg = hex, bold = state.bold })
    state.hl_cache[hex] = name
  end
  return name
end

-- true when every byte is plain ASCII (pattern classes can't express \x00)
local function is_ascii(s)
  for i = 1, #s do
    if s:byte(i) > 127 then return false end
  end
  return true
end

-- --------------------------------------------------------------------------
-- capture / syntax-name -> gradient family
-- --------------------------------------------------------------------------

local function family_of(name)
  if not name then return nil end
  local n = name:lower()
  if n:find('comment') then return state.comments and 'comment_family' or nil end
  if n:find('parameter') then return 'parameter' end
  if n:find('keyword') or n == 'operator' or n:find('conditional')
    or n:find('repeat') or n:find('statement') or n:find('storageclass')
    or n:find('preproc') or n:find('include') or n:find('macro')
    or n:find('exception') or n:find('define') or n:find('label')
    or n:find('directive') or n:find('namespace') then
    return 'keyword'
  end
  if n:find('function') or n:find('method') then return 'func' end
  -- strings intentionally left at their normal (static) highlight, no gradient
  if n:find('string') or n:find('character') or n:find('regex') then return nil end
  -- constants / numbers intentionally left at their normal (static) highlight
  if n:find('number') or n:find('boolean') or n:find('constant')
    or n == 'variable.builtin' or n:find('float') then
    return nil
  end
  if n:find('attribute') then return 'attr' end
  if n:find('tag') then return 'tag' end
  if n:find('type') or n:find('class') or n:find('constructor')
    or n:find('struct') or n:find('enum') then
    return 'type'
  end
  return nil
end

-- comments have no colored ramp; reuse a muted gray ramp
local function ramp_for(fam)
  if fam == 'comment_family' then
    return { state.colors.subtle, state.colors.comment }
  end
  return state.colors.scale[fam]
end

-- --------------------------------------------------------------------------
-- paint one captured node: one interpolated extmark per letter
-- --------------------------------------------------------------------------

local function paint_node(buf, node, fam, top, bottom)
  local ramp = ramp_for(fam)
  if not ramp then return end
  local deep, bright = ramp[1], ramp[#ramp]

  local sr, sc, er, ec = node:range()
  if er < top or sr > bottom then return end

  local ok_txt, text = pcall(vim.treesitter.get_node_text, node, buf)
  if not ok_txt or not text then return end
  -- never split a multibyte (e.g. CJK) byte sequence; leave it to base highlight
  if not is_ascii(text) then return end

  -- total letter count across the (possibly multi-line) node
  local total = 0
  for row = sr, er do
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local c0 = (row == sr) and sc or 0
    local c1 = (row == er) and ec or #line
    if c1 > c0 then total = total + (c1 - c0) end
  end
  if total == 0 then return end

  local offset = 0
  for row = sr, er do
    local in_view = row >= top and row <= bottom
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local c0 = (row == sr) and sc or 0
    local c1 = (row == er) and ec or math.min(#line, MAX_COLS)
    for col = c0, c1 - 1 do
      if in_view then
        local t = (total > 1) and (offset / (total - 1)) or 1
        local hex = grad.mix(deep, bright, t)
        vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
          end_col = col + 1,
          hl_group = hl_for_hex(hex),
          priority = 10000, -- above treesitter (~100)
        })
      end
      offset = offset + 1
    end
  end
end

-- --------------------------------------------------------------------------
-- treesitter path
-- --------------------------------------------------------------------------

local function redraw_treesitter(buf, top, bottom)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok_parser or not parser then return false end
  local ok_query, query = pcall(vim.treesitter.query.get, parser:lang(), 'highlights')
  if not ok_query or not query then return false end

  local trees = parser:parse()
  if not trees[1] then return true end

  -- a node can match several captures; keep the last (most specific) family
  local chosen = {}
  for _, tree in ipairs(trees) do
    for id, node in query:iter_captures(tree:root(), buf, top, bottom + 1) do
      local fam = family_of(query.captures[id])
      if fam then chosen[node] = fam end
    end
  end
  for node, fam in pairs(chosen) do
    paint_node(buf, node, fam, top, bottom)
  end
  return true
end

-- --------------------------------------------------------------------------
-- Vim-syntax fallback: merge runs of columns sharing a syntax name
-- --------------------------------------------------------------------------

local function redraw_syntax(buf, top, bottom)
  local line_count = vim.api.nvim_buf_line_count(buf)
  bottom = math.min(bottom, line_count - 1)
  for row = top, bottom do
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local seg_start, seg_fam = nil, nil
    local function flush(end_col)
      if seg_fam and seg_start then
        local ramp = ramp_for(seg_fam)
        local len = end_col - seg_start
        for col = seg_start, end_col - 1 do
          local t = (len > 1) and ((col - seg_start) / (len - 1)) or 1
          local hex = grad.mix(ramp[1], ramp[#ramp], t)
          vim.api.nvim_buf_set_extmark(buf, ns, row, col, {
            end_col = col + 1, hl_group = hl_for_hex(hex), priority = 10000,
          })
        end
      end
    end
    for col = 0, math.min(#line, MAX_COLS) - 1 do
      local fam
      local stack = vim.fn.synstack(row + 1, col + 1)
      if #stack > 0 then
        fam = family_of(vim.fn.synIDattr(stack[#stack], 'name'))
      end
      if fam ~= seg_fam then
        flush(col)
        seg_start, seg_fam = col, fam
      end
    end
    flush(math.min(#line, MAX_COLS))
  end
end

-- --------------------------------------------------------------------------
-- redraw driver
-- --------------------------------------------------------------------------

local function redraw_buf(buf)
  if not state.enabled then return end
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  if vim.bo[buf].buftype ~= '' then return end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 0 then return end

  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end

  local top = math.max(0, vim.fn.line('w0', win) - 1 - PAD_LINES)
  local bottom = math.min(line_count - 1, vim.fn.line('w$', win) - 1 + PAD_LINES)

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  if not redraw_treesitter(buf, top, bottom) then
    redraw_syntax(buf, top, bottom)
  end
end

local function redraw_visible()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.fn.bufwinid(buf) ~= -1 then
      pcall(redraw_buf, buf)
    end
  end
end

local scheduled = false
local function schedule_redraw()
  if not state.enabled or scheduled then return end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    redraw_visible()
  end)
end

-- --------------------------------------------------------------------------
-- flowing rainbow caret (ported from the VSCode div.cursor animation)
-- --------------------------------------------------------------------------

local function stop_timer()
  if state.cursor_timer then
    state.cursor_timer:stop()
    state.cursor_timer:close()
    state.cursor_timer = nil
  end
end

-- remember the theme's static caret so we can restore it when color is off
local function snapshot_cursor()
  if state.cursor_saved then return end
  state.cursor_saved = {}
  for _, g in ipairs(CURSOR_GROUPS) do
    local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = g, link = false })
    state.cursor_saved[g] = (ok and def) or {}
  end
end

local function restore_cursor()
  if not state.cursor_saved then return end
  for _, g in ipairs(CURSOR_GROUPS) do
    local def = state.cursor_saved[g] or {}
    if next(def) then
      vim.api.nvim_set_hl(0, g, def)
    else
      pcall(vim.cmd, 'highlight! link ' .. g .. ' Cursor')
    end
  end
end

local function start_cursor()
  stop_timer()
  local flow_colors = state.colors.cursor_flow
  if not flow_colors then return end
  state.cursor_index = 0
  state.cursor_timer = uv.new_timer()
  state.cursor_timer:start(0, 110, function()
    state.cursor_index = (state.cursor_index + 1) % #flow_colors
    local hex = flow_colors[state.cursor_index + 1]
    vim.schedule(function()
      for _, g in ipairs(CURSOR_GROUPS) do
        vim.api.nvim_set_hl(0, g, { fg = state.colors.bg_dark, bg = hex, bold = true })
      end
    end)
  end)
end

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

local function clear_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
end

local function attach_autocmds()
  if state.augroup then return end
  state.augroup = vim.api.nvim_create_augroup('NvimpireWordGradient', { clear = true })
  vim.api.nvim_create_autocmd({
    'TextChanged', 'TextChangedI', 'TextChangedP', 'WinScrolled',
    'BufEnter', 'InsertLeave', 'ColorScheme',
  }, {
    group = state.augroup,
    callback = function(ev)
      if ev.event ~= 'ColorScheme' then schedule_redraw() end
    end,
  })
end

local function detach_autocmds()
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
    state.augroup = nil
  end
end

--- (re)configure from resolved settings. Safe to call repeatedly.
function M.setup(settings, colors)
  state.settings = settings
  state.colors = colors
  state.hl_cache = {}
  state.bold = settings.bold ~= false

  local flow_cfg = settings.flow or {}
  -- legacy scope: 'off' disables; 'comment'/'all' enable intra-word gradient
  if flow_cfg.scope == 'off' then
    state.enabled = false
  else
    state.enabled = flow_cfg.enabled ~= false
  end
  state.comments = flow_cfg.comments == true

  detach_autocmds()
  clear_all()
  if state.enabled then
    attach_autocmds()
    schedule_redraw()
  end

  stop_timer()
  if settings.animated_cursor ~= false then
    snapshot_cursor()
    start_cursor()
  else
    restore_cursor()
  end
end

function M.set_enabled(on)
  state.enabled = on
  if on then
    attach_autocmds()
    redraw_visible()
  else
    detach_autocmds()
    clear_all()
  end
end

function M.toggle()
  M.set_enabled(not state.enabled)
  return state.enabled
end

function M.set_cursor(on)
  if on then
    snapshot_cursor()
    start_cursor()
  else
    stop_timer()
    restore_cursor()
  end
end

function M.cursor_enabled()
  return state.cursor_timer ~= nil
end

function M.disable()
  stop_timer()
  restore_cursor()
  detach_autocmds()
  clear_all()
end

-- exposed for tests
M._namespace = ns
M._redraw_visible = redraw_visible

return M
