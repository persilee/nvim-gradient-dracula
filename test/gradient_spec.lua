-- Headless spec: nvim --headless -u NONE --cmd "set rtp+=." -c "luafile test/gradient_spec.lua" -c "qa!"
local failures = {}
local function check(name, cond, extra)
  if cond then
    print(("  [PASS] %s"):format(name))
  else
    failures[#failures + 1] = name
    print(("  [FAIL] %s %s"):format(name, extra or ""))
  end
end

local function hex_of(group)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  return hl.fg and string.format("#%06X", hl.fg) or nil
end

print("== 1. load colorscheme ==")
local ok = pcall(vim.cmd.colorscheme, "nvimpire")
check("colorscheme nvimpire loads", ok)
check("g:colors_name == nvimpire", vim.g.colors_name == "nvimpire", vim.g.colors_name)

local grad = require("nvimpire.gradient")
local colors_mod = require("nvimpire.colors")
local c = colors_mod.colors

print("== 2. gradient engine ==")
check("scale endpoints deep->bright",
  grad.build("dracula", 11).scale.keyword[1] == "#C23594" and
  grad.build("dracula", 11).scale.keyword[11] == "#FF79C6")
check("rainbow ramp has steps", #c.rainbow == 11)
check("cursor flow has 9 VSCode colors", #c.cursor_flow == 9, tostring(#c.cursor_flow))
check("text flow has 9 colors", #c.text_flow == 9)
local mid = grad.mix("#000000", "#FFFFFF", 0.5)
check("mix midpoint ~ #808080", mid == "#808080", mid)

print("== 3. semantic gradient families applied ==")
check("@keyword fg == bright keyword stop", hex_of("@keyword") == c.scale.keyword[11],
  tostring(hex_of("@keyword")))
check("Keyword bold", vim.api.nvim_get_hl(0, { name = "Keyword" }).bold == true)
check("@keyword.return is a DEEPER stop than @keyword",
  hex_of("@keyword.return") == c.scale.keyword[8])
check("@function bright func stop", hex_of("@function") == c.scale.func[11])
check("@string bright string stop", hex_of("@string") == c.scale.string[11])
check("@type bright type stop", hex_of("@type") == c.scale.type[11])
check("@number bright constant stop", hex_of("@number") == c.scale.constant[11])
check("CursorLineNr uses rainbow", hex_of("CursorLineNr") == c.rainbow[1],
  tostring(hex_of("CursorLineNr")))
check("rainbow indent level 1", hex_of("IndentBlanklineIndent1") == c.rainbow[1])
check("ibl v3 char highlight exists", hex_of("@ibl.indent.char.5") == c.rainbow[5])

print("== 4. legacy keys preserved (no nil colors) ==")
local legacy = { "bg","bg_light","bg_lighter","bg_dark","bg_darker","fg","selection",
  "current_line","subtle","comment","cyan","green","orange","pink","purple","red","yellow" }
local missing = {}
for _, k in ipairs(legacy) do if c[k] == nil then missing[#missing+1] = k end end
check("all legacy color keys present", #missing == 0, table.concat(missing, ","))
for i = 0, 15 do if c["color_"..i] == nil then missing[#missing+1] = "color_"..i end end
check("ANSI 0-15 present", #missing == 0, table.concat(missing, ","))
-- scan every group for nil fg/bg
local group_list = { "core","code","lsp","treesitter","telescope","nvim-tree","neotree",
  "gitsigns","cmp","trouble","navic","mason","fidget","notify","illuminate",
  "indent-blankline","harpoon" }
local nil_groups = {}
for _, gname in ipairs(group_list) do
  local g = require("nvimpire.groups." .. gname).get({})
  for hg, attrs in pairs(g) do
    if attrs.fg == nil and attrs.bg == nil and attrs.sp == nil and not attrs.link then
      -- allow intentionally-empty text groups
      if not hg:match("^@text") and hg ~= "@none" then
        nil_groups[#nil_groups+1] = gname..":"..hg
      end
    end
  end
end
check("no group has unresolved nil color", #nil_groups == 0, table.concat(nil_groups, ","))

print("== 5. switch all 4 styles at runtime ==")
local theme = require("nvimpire")
for _, style in ipairs(grad.style_names) do
  local before = colors_mod.colors.bg
  pcall(theme.set_style, style)
  local cc = colors_mod.colors
  local ok_s = cc.style_name == style and #cc.scale.keyword == 11
  check("style "..style.." applied", ok_s, cc.style_name or "?")
end

print("== 6. intra-word flowing gradient (extmarks) ==")
vim.cmd("enew")
vim.bo.filetype = "lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "local color = 42",
  "local function hello() return \"dracula\" end",
})
local nsid = vim.api.nvim_get_namespaces()["nvimpire_word_gradient"]
check("word-gradient namespace exists", nsid ~= nil)
theme.flow._redraw_visible()
local marks = vim.api.nvim_buf_get_extmarks(0, nsid, 0, -1, { details = true })
check("colored words produce per-letter extmarks", #marks >= 8, tostring(#marks))
theme.flow.set_enabled(false)
local marks_off = vim.api.nvim_buf_get_extmarks(0, nsid, 0, -1, {})
check("set_enabled(false) clears extmarks", #marks_off == 0, tostring(#marks_off))
theme.flow.set_enabled(true)

print("== 7. user commands ==")
local cmds = vim.api.nvim_get_commands({})
check(":NvimpireGradientFlow registered", cmds.NvimpireGradientFlow ~= nil)
check(":NvimpireGradientCursor registered", cmds.NvimpireGradientCursor ~= nil)
check(":NvimpireGradientStyle registered", cmds.NvimpireGradientStyle ~= nil)
pcall(vim.cmd, "NvimpireGradientStyle dracula")
pcall(vim.cmd, "NvimpireGradientCursor off")

print("== 8. lualine gradient theme ==")
local ll = require("lualine.themes.nvimpire")
check("lualine has normal/insert/visual/replace/command/inactive",
  ll.normal and ll.insert and ll.visual and ll.replace and ll.command and ll.inactive)
check("lualine normal.a is solid keyword gradient",
  ll.normal.a.bg == c.scale.keyword[11], tostring(ll.normal.a.bg))

theme.flow.disable()

print("")
if #failures == 0 then
  print("ALL CHECKS PASSED")
else
  print("FAILURES: " .. #failures)
  vim.cmd("cquit 1")
end
