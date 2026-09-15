local lib = require('nvimpire.lib')
local colors_mod = require('nvimpire.colors')

local M = {
  has_options = false
}

local defaults = {
  transparent = false,

  -- --- gradient configuration (ported from VSCode gradient-theme) ---------
  -- gradient palette: "dracula" | "monokai" | "firefox" | "bearded"
  style = 'dracula',
  -- number of discrete stops interpolated for every gradient
  steps = 11,
  -- VSCode renders every gradient token with font-weight:700
  bold = true,
  italic_comments = true,
  -- rainbow ramps for indent guides / matching pairs / line numbers
  rainbow_indent = true,
  -- animate the caret through the flowing rainbow gradient
  animated_cursor = true,
  -- sync :terminal / `g:terminal_color_0..15` with the active palette
  terminal_colors = true,
  -- intra-word flowing gradient: each colored word flows deep -> bright
  -- from its first letter to its last (Neovim extmarks over treesitter)
  flow = {
    enabled = true,
    comments = false, -- also gradient-flow comments (muted gray ramp)
  },
}

-- Option aliases accepted from user configs (e.g. when the plugin is renamed
-- for a package manager). Left side = alias, right side = canonical key.
local aliases = {
  transparent_bg = 'transparent',
  italic_comment = 'italic_comments',
  terminal_color = 'terminal_colors',
}

M.settings = lib.deep_copy(defaults)

function M.config(opts)
  opts = opts or {}

  -- normalize aliases onto the canonical option names
  for alias, canonical in pairs(aliases) do
    if opts[alias] ~= nil then
      if opts[canonical] == nil then opts[canonical] = opts[alias] end
      opts[alias] = nil
    end
  end

  M.settings = lib.extend(M.settings, opts)
  M.has_options = true
end

function M.reset()
  M.settings = lib.deep_copy(defaults)
  M.has_options = false
end

local function hl(group, properties)
  vim.api.nvim_set_hl(0, group, properties)
end

function M.initialize_group(group)
  for group_name, properties in pairs(group) do
    hl(group_name, properties)
  end
end

function M.load_groups(groups)
  -- (re)build gradient colors from the active settings before any group reads
  -- the shared color table
  colors_mod.refresh(M.settings.style, M.settings.steps)

  for _, group_name in next, groups, nil do
    local group = require('nvimpire.groups.' .. group_name)
    M.initialize_group(group.get(M.settings))
  end
end

return M
