local c = require('nvimpire.colors').colors

local M = {}

-- Each syntax family walks a different position along its own gradient ramp
-- (ramp index 1 = deep stop, index #ramp = bright stop), so related groups
-- read as one gradient band instead of unrelated flat colors.
function M.get(settings)
  settings = settings or {}
  local bold = settings.bold ~= false
  local italic_comments = settings.italic_comments ~= false

  local kw = c.scale.keyword
  local fn = c.scale.func
  local str = c.scale.string
  local tp = c.scale.type
  local ct = c.scale.constant
  local pm = c.scale.parameter
  local tag = c.scale.tag
  local attr = c.scale.attr

  local groups = {
    ["@none"] = { fg = c.none, bg = c.none },
    ["@comment"] = { fg = c.comment, bg = c.none, italic = true },
    ["@preproc"] = { fg = kw[7], bg = c.none },
    ["@define"] = { fg = kw[7], bg = c.none },
    ["@operator"] = { fg = kw[11], bg = c.none, bold = true },
    ["@punctuation.delimeter"] = { fg = c.fg, bg = c.none },
    ["@punctuation.bracket"] = { fg = c.fg, bg = c.none },
    ["@punctuation.special"] = { fg = kw[9], bg = c.none },

    -- string gradient family
    ["@string"] = { fg = str[11], bg = c.none },
    ["@string.regex"] = { fg = c.red, bg = c.none },
    ["@string.escape"] = { fg = tp[9], bg = c.none },

    -- constant / number gradient family (purple)
    ["@boolean"] = { fg = ct[11], bg = c.none, bold = true },
    ["@character"] = { fg = kw[10], bg = c.none },
    ["@character.special"] = { fg = tp[9], bg = c.none },
    ["@number"] = { fg = ct[11], bg = c.none },
    ["@float"] = { fg = ct[11], bg = c.none },

    -- function gradient family (green -> cyan)
    ["@function"] = { fg = fn[11], bg = c.none, bold = true },
    ["@function.builtin"] = { fg = tp[9], bg = c.none },
    ["@function.call"] = { fg = fn[10], bg = c.none },
    ["@function.macro"] = { fg = kw[8], bg = c.none },
    ["@method"] = { fg = fn[11], bg = c.none, bold = true },
    ["@method.call"] = { fg = fn[10], bg = c.none },
    ["@constructor"] = { fg = tp[9], bg = c.none },

    -- parameter gradient family (orange)
    ["@parameter"] = { fg = pm[11], bg = c.none, italic = true },

    -- keyword gradient family (pink)
    ["@keyword"] = { fg = kw[11], bg = c.none, bold = true },
    ["@keyword.function"] = { fg = kw[9], bg = c.none, bold = true },
    ["@keyword.operator"] = { fg = kw[10], bg = c.none, bold = true },
    ["@keyword.return"] = { fg = kw[8], bg = c.none, bold = true },
    ["@keyword.export"] = { fg = kw[7], bg = c.none },
    ["@conditional"] = { fg = kw[10], bg = c.none, bold = true },
    ["@repeat"] = { fg = kw[9], bg = c.none, bold = true },
    ["@debug"] = { fg = tp[8], bg = c.none },
    ["@label"] = { fg = kw[7], bg = c.none },
    ["@include"] = { fg = kw[8], bg = c.none },
    ["@exception"] = { fg = kw[8], bg = c.none },

    -- type gradient family (cyan/blue)
    ["@type"] = { fg = tp[11], bg = c.none, italic = true },
    ["@type.builtin"] = { fg = tp[10], bg = c.none, italic = true },
    ["@type.definition"] = { fg = tp[9], bg = c.none, italic = true },
    ["@type.qualifier"] = { fg = kw[8], bg = c.none, italic = true },
    ["@storageclass"] = { fg = kw[8], bg = c.none },
    ["@attribute"] = { fg = kw[7], bg = c.none },

    ["@field"] = { fg = c.fg, bg = c.none },
    ["@property"] = { fg = c.fg, bg = c.none },
    ["@variable"] = { fg = c.fg, bg = c.none },
    ["@variable.builtin"] = { fg = ct[9], bg = c.none },

    ["@constant"] = { fg = ct[11], bg = c.none },
    ["@constant.builtin"] = { fg = ct[10], bg = c.none },
    ["@constant.macro"] = { fg = kw[8], bg = c.none },
    ["@namespace"] = { fg = kw[6], bg = c.none },
    ["@symbol"] = { fg = c.fg, bg = c.none },

    ["@text"] = { fg = c.none, bg = c.none },
    ["@text.strong"] = { fg = c.none, bg = c.none, bold = true },
    ["@text.emphasis"] = { fg = c.none, bg = c.none, italic = true },
    ["@text.underline"] = { fg = c.none, bg = c.none, underline = true },
    ["@text.strike"] = { fg = c.none, bg = c.none, strikethrough = true },
    ["@text.title"] = { fg = fn[11], bg = c.none, bold = true },
    ["@text.literal"] = { fg = str[10], bg = c.none },
    ["@text.uri"] = { fg = c.none, bg = c.none, underline = true },
    ["@text.math"] = { fg = tp[9], bg = c.none },
    ["@text.environment"] = { fg = kw[7], bg = c.none },
    ["@text.environment.name"] = { fg = tp[9], bg = c.none, italic = true },
    ["@text.reference"] = { fg = ct[9], bg = c.none },
    ["@text.todo"] = { fg = tp[11], bg = c.none, bold = true },
    ["@text.note"] = { fg = tp[10], bg = c.none, italic = true },
    ["@text.warning"] = { fg = c.orange, bg = c.none, bold = true },
    ["@text.danger"] = { fg = c.red, bg = c.none, bold = true },

    -- tag gradient family (gold -> pink)
    ["@tag"] = { fg = tag[11], bg = c.none, bold = true },
    ["@tag.attribute"] = { fg = attr[11], bg = c.none, italic = true },
    ["@tag.delimiter"] = { fg = c.fg, bg = c.none },

    ["@definition.parameter"] = { fg = pm[11], bg = c.none, italic = true },

    ["@constructur.typescript"] = {
      fg = ct[10],
      bg = c.none,
    },

    -- TSX
    ["@tag.attribute.tsx"] = { fg = attr[11], italic = true },
    ["@tag.delimiter.tsx"] = { fg = c.fg, bg = c.none },

    -- JSON
    ["@label.json"] = { fg = tp[10], bg = c.none },
  }

  if not bold then
    for _, v in pairs(groups) do v.bold = nil end
  end
  if not italic_comments then
    groups["@comment"].italic = nil
  end

  return groups
end

return M
