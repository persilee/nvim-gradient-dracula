-- ============================================================================
-- nvimpire/gradient.lua
-- ----------------------------------------------------------------------------
-- Gradient engine. Turns the multi-stop CSS gradients of the VSCode
-- `shaobeichen/gradient-theme` extension into discrete color ramps that a
-- terminal (Neovim highlight groups) can actually render.
--
-- A terminal highlight group only accepts ONE foreground color, so a word
-- cannot be filled with a continuous CSS gradient. Instead we:
--   1. interpolate every VSCode `linear-gradient(...)` pair into N stops,
--   2. expose the BRIGHT stop as the semantic color (the VSCode gradients all
--      end on a bright color and use font-weight:700),
--   3. expose the full ramp so a *family* of related highlight groups
--      (keyword / keyword.operator / keyword.return ...) can sit at different
--      positions along the same gradient, which reads as a gradient band.
--
-- The palettes below are ported 1:1 from the VSCode theme's src/*/index.css.
-- ============================================================================

local M = {}

-- --------------------------------------------------------------------------
-- color math
-- --------------------------------------------------------------------------

--- "#rgb" / "#rrggbb" -> { r, g, b } (0-255)
function M.hex_to_rgb(hex)
  hex = (hex or ""):gsub("#", "")
  if #hex == 3 then
    local r, g, b = hex:match("(.)(.)(.)")
    hex = r .. r .. g .. g .. b .. b
  end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  assert(r and g and b, "nvimpire.gradient: invalid hex color")
  return { r = r, g = g, b = b }
end

local function clamp255(v)
  v = math.floor(v + 0.5)
  if v < 0 then return 0 end
  if v > 255 then return 255 end
  return v
end

--- {r,g,b} -> "#rrggbb"
function M.rgb_to_hex(rgb)
  return string.format("#%02X%02X%02X", clamp255(rgb.r), clamp255(rgb.g), clamp255(rgb.b))
end

--- linear interpolation between two hex colors. t in [0,1].
function M.mix(c1, c2, t)
  local a = M.hex_to_rgb(c1)
  local b = M.hex_to_rgb(c2)
  t = math.max(0, math.min(1, t))
  return M.rgb_to_hex({
    r = a.r + (b.r - a.r) * t,
    g = a.g + (b.g - a.g) * t,
    b = a.b + (b.b - a.b) * t,
  })
end

--- lighten (t>0) / darken (t<0) a hex color toward white / black.
function M.tint(hex, t)
  if t >= 0 then
    return M.mix(hex, "#FFFFFF", t)
  else
    return M.mix(hex, "#000000", -t)
  end
end

--- Build a ramp of `n` colors spread across several gradient stops.
--- stops: { "#..", "#..", ... }  returns n hex colors, first == stops[1],
--- last == stops[#stops], intermediate stops honored in order.
function M.scale(stops, n)
  assert(type(stops) == "table" and #stops >= 2, "need >=2 gradient stops")
  n = math.max(2, n or 11)
  local out = {}
  local segments = #stops - 1
  for i = 0, n - 1 do
    local pos = (i / (n - 1)) * segments
    local seg = math.floor(pos)
    local local_t = pos - seg
    if seg >= segments then
      seg = segments - 1
      local_t = 1
    end
    out[i + 1] = M.mix(stops[seg + 1], stops[seg + 2], local_t)
  end
  return out
end

--- safely index a ramp by 1-based position, clamping at both ends.
function M.at(ramp, i)
  if not ramp or #ramp == 0 then return nil end
  i = math.floor(i)
  if i < 1 then i = 1 end
  if i > #ramp then i = #ramp end
  return ramp[i]
end

-- --------------------------------------------------------------------------
-- Shared VSCode gradients (identical across every VSCode sub-theme)
-- --------------------------------------------------------------------------

-- active editor-tab top border: linear-gradient(to right, gold,pink,green,blue)
local RAINBOW = { "#EACD61", "#EA618E", "#3CEC85", "#61AFEA" }

-- flowing rainbow caret (bearded-arc-woodfishhhh `div.cursor`)
local CURSOR_FLOW = {
  "#FF2D95", "#FF4500", "#FFD700", "#7CFC00", "#00FFFF",
  "#1E90FF", "#9370DB", "#FF00FF", "#FF1493",
}

-- default-text 8-color gradient (`.mtk1`)
local TEXT_FLOW = {
  "#FFC1E0", "#FFD5C6", "#FFF6C5", "#E0FFC1", "#BDFFFF",
  "#C3E1FF", "#D7C4FF", "#FFC0FF", "#FFC8E5",
}

-- --------------------------------------------------------------------------
-- Ported palettes.
-- base = editor chrome colors; sem = { deep -> bright } per syntax family,
-- taken straight from the VSCode theme's linear-gradient pairs.
-- --------------------------------------------------------------------------

M.styles = {
  -- gradient-dracula-theme (nvimpire's native Dracula base) ----------------
  dracula = {
    label = "Gradient Dracula",
    base = {
      bg = "#282A36",
      bg_light = "#343746",
      bg_lighter = "#424450",
      bg_dark = "#21222C",
      bg_darker = "#191A21",
      fg = "#F8F8F2",
      selection = "#44475A",
      current_line = "#44475A",
      subtle = "#7D8199",
      comment = "#b2bbc2",
    },
    sem = {
      keyword   = { "#C23594", "#FF79C6" }, -- pink
      func      = { "#109b93", "#50FA7B" }, -- VSCode #11998f -> #38ef7d
      string    = { "#C9E34B", "#F1FA8C" }, -- yellow
      type      = { "#2EC5E6", "#8BE9FD" }, -- cyan
      constant  = { "#8B5CF6", "#BD93F9" }, -- purple
      parameter = { "#FF7A3D", "#FFB86C" }, -- orange
      tag       = { "#FF61D2", "#FE908F" }, -- VSCode dracula tag pair
      attr      = { "#11998F", "#38EF7D" }, -- VSCode dracula attr pair
      operator  = { "#E056B0", "#FF9ED2" },
      error     = { "#E63E4E", "#FF5555" },
      warn      = { "#E08A19", "#FFB86C" },
      info      = { "#2EC5E6", "#8BE9FD" },
      hint      = { "#8B5CF6", "#BD93F9" },
    },
    rainbow = RAINBOW,
    cursor_flow = CURSOR_FLOW,
    text_flow = TEXT_FLOW,
  },

  -- gradient-monokai-pro / -classic ----------------------------------------
  monokai = {
    label = "Gradient Monokai Pro",
    base = {
      bg = "#2D2A2E",
      bg_light = "#383539",
      bg_lighter = "#403E41",
      bg_dark = "#221F22",
      bg_darker = "#19181A",
      fg = "#FCFCFA",
      selection = "#403E41",
      current_line = "#403E41",
      subtle = "#403E41",
      comment = "#727072",
    },
    sem = {
      keyword   = { "#DB3371", "#FF6188" }, -- VSCode #db3371 -> #ff9ec2
      func      = { "#70B344", "#A9DC76" },
      string    = { "#C9A13A", "#FFD866" }, -- VSCode #e08a19 -> #e6db74
      type      = { "#0792AE", "#78DCE8" }, -- VSCode #0792ae -> #8ae1f3
      constant  = { "#9368E9", "#AB9DF2" },
      parameter = { "#E0702A", "#FC9867" },
      tag       = { "#DB3371", "#FF9EC2" },
      attr      = { "#0792AE", "#8AE1F3" },
      operator  = { "#C8506A", "#FF8AA8" },
      error     = { "#E03E4C", "#FF5263" },
      warn      = { "#E08A19", "#FC9867" },
      info      = { "#0792AE", "#78DCE8" },
      hint      = { "#9368E9", "#AB9DF2" },
    },
    rainbow = RAINBOW,
    cursor_flow = CURSOR_FLOW,
    text_flow = TEXT_FLOW,
  },

  -- gradient-developer-theme-firefox-dark ----------------------------------
  firefox = {
    label = "Gradient Firefox Dark",
    base = {
      bg = "#23293B",
      bg_light = "#2E364D",
      bg_lighter = "#3A435C",
      bg_dark = "#181D27",
      bg_darker = "#10141C",
      fg = "#F9F9F9",
      selection = "#2E4052",
      current_line = "#2E364D",
      subtle = "#3A435C",
      comment = "#6B7480",
    },
    sem = {
      keyword   = { "#0975CE", "#6CB6FF" }, -- VSCode mtk6 blue
      func      = { "#2DE28B", "#3EE896" }, -- VSCode mtk4 green
      string    = { "#F5FF43", "#F0FF70" }, -- VSCode mtk15 yellow
      type      = { "#15DBE2", "#9CECFE" }, -- VSCode mtk7 cyan-white
      constant  = { "#6B89FF", "#A47EFA" }, -- VSCode mtk5 indigo
      parameter = { "#F561F1", "#F08BFF" }, -- VSCode mtk8 magenta
      tag       = { "#FF4B8F", "#FD619C" }, -- VSCode mtk12 pink
      attr      = { "#0975CE", "#90CCFF" },
      operator  = { "#5A7AE0", "#B4C6FF" },
      error     = { "#E64757", "#FF6170" },
      warn      = { "#D8B02A", "#FFD866" },
      info      = { "#15DBE2", "#9CECFE" },
      hint      = { "#6B89FF", "#A47EFA" },
    },
    rainbow = RAINBOW,
    cursor_flow = CURSOR_FLOW,
    text_flow = TEXT_FLOW,
  },

  -- gradient-bearded-theme-arc-woodfishhhh (the most complete VSCode one) ---
  bearded = {
    label = "Gradient Bearded Arc",
    base = {
      bg = "#1E2030",
      bg_light = "#292C42",
      bg_lighter = "#33374F",
      bg_dark = "#191B29",
      bg_darker = "#141622",
      fg = "#CAD3F5",
      selection = "#2F334D",
      current_line = "#292C42",
      subtle = "#33374F",
      comment = "#8189A6",
    },
    sem = {
      keyword   = { "#B78AFF", "#D874FF" }, -- VSCode declaration purple
      func      = { "#22ECDB", "#1FD6F2" }, -- VSCode cyan -> blue
      string    = { "#00FF04", "#26FF80" }, -- VSCode green
      type      = { "#00D4FF", "#2EC0FF" }, -- VSCode tag-name cyan-blue
      constant  = { "#FF9900", "#FFD24A" }, -- VSCode orange -> lime
      parameter = { "#FF738A", "#FF7A66" }, -- VSCode primitive red-orange
      tag       = { "#EACD61", "#EC9477" }, -- VSCode gold -> pink
      attr      = { "#EACD61", "#EA618E" },
      operator  = { "#B78AFF", "#F644FF" },
      error     = { "#FF6B81", "#FF5C5C" },
      warn      = { "#EACD61", "#FFD24A" },
      info      = { "#22ECDB", "#00BBFF" },
      hint      = { "#B78AFF", "#F644FF" },
    },
    rainbow = RAINBOW,
    cursor_flow = CURSOR_FLOW,
    text_flow = TEXT_FLOW,
  },
}

M.style_names = { "dracula", "monokai", "firefox", "bearded" }

function M.is_valid_style(name)
  return M.styles[name] ~= nil
end

-- --------------------------------------------------------------------------
-- Build the resolved color table for one style.
--
-- Returns:
--   colors             -- flat table, keeps every legacy nvimpire key so the
--                         existing highlight groups keep working unchanged
--   colors.scale       -- { family = {hex...} } ramps (deep -> bright)
--   colors.rainbow     -- cyclic rainbow ramp
--   colors.cursor_flow -- caret animation colors
--   colors.text_flow   -- per-character text gradient colors
-- --------------------------------------------------------------------------
function M.build(style_name, steps)
  local style = M.styles[style_name] or M.styles.dracula
  steps = math.max(3, steps or 11)

  local b = style.base
  local c = {}

  -- editor chrome -----------------------------------------------------------
  c.bg = b.bg
  c.bg_light = b.bg_light
  c.bg_lighter = b.bg_lighter
  c.bg_dark = b.bg_dark
  c.bg_darker = b.bg_darker
  c.fg = b.fg
  c.selection = b.selection
  c.current_line = b.current_line
  c.subtle = b.subtle
  c.comment = b.comment

  -- semantic BRIGHT stops (back-compat with legacy color keys) --------------
  local function bright(fam) return style.sem[fam][2] end
  c.pink   = bright("keyword")
  c.green  = bright("func")
  c.yellow = bright("string")
  c.cyan   = bright("type")
  c.purple = bright("constant")
  c.orange = bright("parameter")
  c.red    = bright("error")

  -- semantic DEEP stops (new keys) ------------------------------------------
  local function deep(fam) return style.sem[fam][1] end
  c.keyword_deep   = deep("keyword")
  c.func_deep      = deep("func")
  c.string_deep    = deep("string")
  c.type_deep      = deep("type")
  c.constant_deep  = deep("constant")
  c.parameter_deep = deep("parameter")
  c.tag_deep       = deep("tag")
  c.attr_deep      = deep("attr")

  -- ramps -------------------------------------------------------------------
  local scale      = {}
  for fam, pair in pairs(style.sem) do
    scale[fam] = M.scale(pair, steps)
  end
  -- rainbow ramp is cyclic: append the first stop so it loops seamlessly
  local rainbow     = M.scale(style.rainbow, steps + 1)
  rainbow[#rainbow] = nil
  c.scale           = scale
  c.rainbow         = rainbow
  c.cursor_flow     = style.cursor_flow
  c.text_flow       = style.text_flow
  c.style_name      = style_name
  c.style_label     = style.label

  -- ANSI palette ------------------------------------------------------------
  c.color_0         = c.bg_dark
  c.color_1         = c.red
  c.color_2         = c.green
  c.color_3         = c.yellow
  c.color_4         = c.purple
  c.color_5         = c.pink
  c.color_6         = c.cyan
  c.color_7         = c.fg
  c.color_8         = c.comment
  c.color_9         = M.tint(c.red, 0.25)
  c.color_10        = M.tint(c.green, 0.25)
  c.color_11        = M.tint(c.yellow, 0.25)
  c.color_12        = M.tint(c.purple, 0.25)
  c.color_13        = M.tint(c.pink, 0.25)
  c.color_14        = M.tint(c.cyan, 0.25)
  c.color_15        = "#FFFFFF"

  c.none            = "NONE"
  return c
end

return M
