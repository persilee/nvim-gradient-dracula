local c = require('nvimpire.colors').colors

local M = {}

function M.get(settings)
  settings = settings or {}
  local rainbow = settings.rainbow_indent ~= false

  -- legacy indent-blankline.nvim (v2) indent levels
  local function legacy(i, fallback)
    return { fg = rainbow and c.rainbow[i] or fallback, bg = c.none, nocombine = true }
  end

  local groups = {
    IndentBlanklineIndent1 = legacy(1, c.comment),
    IndentBlanklineIndent2 = legacy(3, c.cyan),
    IndentBlanklineIndent3 = legacy(5, c.green),
    IndentBlanklineIndent4 = legacy(7, c.yellow),
    IndentBlanklineIndent5 = legacy(9, c.orange),
    IndentBlanklineIndent6 = legacy(11, c.red),

    -- current scope
    IndentBlanklineContextStart = { sp = c.pink, underline = true },
    IndentBlanklineContextChar = { fg = c.pink, nocombine = true },
  }

  -- indent-blankline.nvim v3 ("ibl"): expose the whole rainbow ramp so users
  -- can set `indent.highlight = { "@ibl.indent.char.1", ... }`
  for i = 1, #c.rainbow do
    groups[string.format('@ibl.indent.char.%d', i)] = {
      fg = rainbow and c.rainbow[i] or c.comment,
      nocombine = true,
    }
  end
  groups['IblIndent'] = { fg = c.comment, nocombine = true }
  groups['IblScope'] = { fg = c.pink, nocombine = true }

  return groups
end

return M
