local c = require('nvimpire.colors').colors

local nvimpire = {}

-- Each section sits at a different point along the gradient ramps, so the
-- statusline reads as one flowing gradient band. The `a` (mode) segment is a
-- solid gradient color with dark text; the mode changes which gradient it uses.
local function mode_segment(fg)
  return { fg = c.bg_dark, bg = fg, bold = true }
end

nvimpire.normal = {
  a = mode_segment(c.scale.keyword[11]),
  b = { fg = c.scale.func[11], bg = c.bg_light },
  c = { fg = c.fg, bg = c.bg_dark },
  x = { fg = c.scale.type[11], bg = c.bg_dark },
  y = { fg = c.scale.constant[11], bg = c.bg_darker },
  z = { fg = c.rainbow[1], bg = c.bg_darker, bold = true },
}

nvimpire.insert = {
  a = mode_segment(c.scale.type[11]),
  b = { fg = c.scale.func[11], bg = c.bg_light },
  c = { fg = c.fg, bg = c.bg_dark },
  x = { fg = c.scale.type[11], bg = c.bg_dark },
  y = { fg = c.scale.constant[11], bg = c.bg_darker },
  z = { fg = c.rainbow[2], bg = c.bg_darker, bold = true },
}

nvimpire.visual = {
  a = mode_segment(c.scale.constant[11]),
  b = { fg = c.scale.func[11], bg = c.bg_light },
  c = { fg = c.fg, bg = c.bg_dark },
  x = { fg = c.scale.type[11], bg = c.bg_dark },
  y = { fg = c.scale.constant[11], bg = c.bg_darker },
  z = { fg = c.rainbow[3], bg = c.bg_darker, bold = true },
}

nvimpire.replace = {
  a = mode_segment(c.red),
  b = { fg = c.scale.func[11], bg = c.bg_light },
  c = { fg = c.fg, bg = c.bg_dark },
  x = { fg = c.scale.type[11], bg = c.bg_dark },
  y = { fg = c.scale.constant[11], bg = c.bg_darker },
  z = { fg = c.rainbow[4], bg = c.bg_darker, bold = true },
}

nvimpire.command = {
  a = mode_segment(c.scale.string[11]),
  b = { fg = c.scale.func[11], bg = c.bg_light },
  c = { fg = c.fg, bg = c.bg_dark },
  x = { fg = c.scale.type[11], bg = c.bg_dark },
  y = { fg = c.scale.constant[11], bg = c.bg_darker },
  z = { fg = c.rainbow[1], bg = c.bg_darker, bold = true },
}

nvimpire.inactive = {
  a = { fg = c.comment, bg = c.none },
  b = { fg = c.comment, bg = c.bg_darker },
  c = { fg = c.comment, bg = c.bg_dark },
  x = { fg = c.comment, bg = c.bg_dark },
  y = { fg = c.comment, bg = c.bg_darker },
  z = { fg = c.comment, bg = c.bg_darker },
}

return nvimpire
