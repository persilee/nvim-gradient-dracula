local c = require('nvimpire.colors').colors

local M = {}

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

  local groups = {
    Comment = { fg = c.comment, bg = c.none, italic = true },
    Variable = { fg = c.fg, bg = c.none },
    Underlined = { fg = c.fg, bg = c.none, underline = true },
    Todo = { fg = tp[11], bg = c.none, bold = true },
    Error = { fg = c.red, bg = c.none },

    -- constant / number family (purple gradient)
    Constant = { fg = ct[11], bg = c.none },
    Number = { fg = ct[11], bg = c.none },
    Bool = { fg = ct[11], bg = c.none, bold = true },
    Float = { fg = ct[11], bg = c.none },

    -- string family (yellow gradient)
    String = { fg = str[11], bg = c.none },
    Character = { fg = kw[10], bg = c.none },

    Identifier = { fg = c.fg, bg = c.none },

    -- function family (green gradient)
    Function = { fg = fn[11], bg = c.none, bold = true },

    -- keyword / statement family (pink gradient)
    Statement = { fg = kw[11], bg = c.none, bold = true },
    Conditional = { fg = kw[10], bg = c.none, bold = true },
    Repeat = { fg = kw[9], bg = c.none, bold = true },
    Label = { fg = kw[7], bg = c.none },
    Operator = { fg = kw[11], bg = c.none, bold = true },
    Keyword = { fg = kw[11], bg = c.none, bold = true },
    Exception = { fg = kw[8], bg = c.none },
    PreProc = { fg = kw[8], bg = c.none },
    Include = { fg = kw[8], bg = c.none },
    Define = { fg = kw[7], bg = c.none },
    Debug = { fg = tp[8], bg = c.none },
    Macro = { fg = kw[8], bg = c.none },
    PreCondit = { fg = kw[7], bg = c.none },
    StorageClass = { fg = kw[8], bg = c.none },
    Structure = { fg = tp[9], bg = c.none },
    Typedef = { fg = tp[9], bg = c.none },

    -- type family (cyan gradient)
    Type = { fg = tp[11], bg = c.none, italic = true },

    Delimiter = { fg = c.fg, bg = c.none },
    Special = { fg = tp[10], bg = c.none },
    SpecialChar = { fg = tp[9], bg = c.none },
    SpecialComment = { fg = tp[9], bg = c.none, italic = true },

    -- tag family (gold -> pink gradient)
    Tag = { fg = tag[11], bg = c.none, bold = true },
    Title = { fg = fn[11], bg = c.none, bold = true },

    helperHyperTextJump = { fg = tp[11], bg = c.none, underline = true },
    helpCommand = { fg = ct[11], bg = c.none },
    helpExample = { fg = fn[10], bg = c.none },
    helpBacktick = { fg = pm[11], bg = c.none },


    -- TODO
    -- MARKDOWN
    -- HTML
    -- CSS

    -- NeoVim
    healthError = { fg = c.red },
    healthSuccess = { fg = c.green },
    healthWarning = { fg = c.orange },

    markdownHeadingDelimiter = { fg = c.orange, bold = true },
    markdownCode = { fg = tp[10] },
    markdownCodeBlock = { fg = tp[10] },
    markdownH1 = { fg = c.purple, bold = true }, -- was c.pruple (typo) upstream
    markdownH2 = { fg = c.green, bold = true },
    markdownLinkText = { fg = c.yellow, underline = true },
  }

  if not bold then
    for _, v in pairs(groups) do v.bold = nil end
  end
  if not italic_comments then
    groups.Comment.italic = nil
  end

  return groups
end

return M
