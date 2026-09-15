-- Core effect: each colored WORD flows deep->bright letter by letter.
-- Run: nvim --headless -u NONE --cmd "set rtp+=." -c "luafile test/word_gradient_spec.lua" -c "qa!"
for _, p in ipairs(vim.api.nvim_get_runtime_file("lua", true)) do
  package.path = p .. "/?.lua;" .. p .. "/?/init.lua;" .. package.path
end

local grad = require("nvimpire.gradient")
local theme = require("nvimpire")
theme.setup({ style = "dracula", animated_cursor = false, flow = { enabled = true } })

local fails = {}
local function check(name, cond, extra)
  if cond then print("  [PASS] "..name) else fails[#fails+1]=name; print("  [FAIL] "..name.." "..tostring(extra)) end
end

vim.cmd("enew")
vim.bo.filetype = "lua"
--            01234567890123456789012
-- local[0,5) value[6,11) =[12,13) mix[14,17) ( 42[18,20) )
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = mix(42)" })
local ns = vim.api.nvim_get_namespaces()["nvimpire_word_gradient"]
theme.flow._redraw_visible()

local c = require("nvimpire.colors").colors
local all = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })

local function fghex(m)
  local grp = m[4].hl_group
  local hl = type(grp) == "number"
    and vim.api.nvim_get_hl(0, { id = grp })
    or vim.api.nvim_get_hl(0, { name = grp, link = false })
  return string.format("#%06X", hl.fg or 0)
end
local function range_colors(s, e) -- row 0, columns [s,e)
  local out = {}
  for _, m in ipairs(all) do
    if m[2] == 0 and m[3] >= s and m[3] < e then out[m[3] - s + 1] = fghex(m) end
  end
  return out
end

print("== gradient letters are bold ==")
do
  local grp = all[1][4].hl_group
  local hl = type(grp) == "number" and vim.api.nvim_get_hl(0, { id = grp })
    or vim.api.nvim_get_hl(0, { name = grp, link = false })
  check("per-letter highlight is bold", hl.bold == true, tostring(hl.bold))
end

print("== keyword 'local' flows deep pink -> bright pink ==")
local kw = c.scale.keyword
local kwc = range_colors(0, 5)
check("5 letters each painted", #kwc == 5, tostring(#kwc))
check("first letter == deep stop", kwc[1] == kw[1], kwc[1].." vs "..kw[1])
check("last letter == bright stop", kwc[5] == kw[11], kwc[5].." vs "..kw[11])
check("middle letter == 50% mix", kwc[3] == grad.mix(kw[1], kw[11], 0.5), kwc[3])
local mono = kwc[1]~=kwc[2] and kwc[2]~=kwc[3] and kwc[3]~=kwc[4] and kwc[4]~=kwc[5]
check("every adjacent letter differs (true gradient)", mono)

print("== function 'mix' flows deep green -> bright green ==")
local fn = c.scale.func
local fnc = range_colors(14, 17)
check("mix first == func deep", fnc[1] == fn[1], tostring(fnc[1]))
check("mix last == func bright", fnc[3] == fn[11], tostring(fnc[3]))

print("== number '42' flows deep purple -> bright purple ==")
local ct = c.scale.constant
local nc = range_colors(18, 20)
check("42 first == constant deep", nc[1] == ct[1], tostring(nc[1]))
check("42 last == constant bright", nc[2] == ct[11], tostring(nc[2]))

print("== different families keep their own hue ==")
check("keyword pink != function green", kwc[5] ~= fnc[3])
check("function green != number purple", fnc[3] ~= nc[2])

print("== plain identifier 'value' is left ungraded ==")
local plain = range_colors(6, 11)
check("plain variable has no word-gradient marks", #plain == 0, tostring(#plain))

print("== disabling clears the per-letter marks ==")
theme.flow.set_enabled(false)
local off = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
check("marks cleared after disable", #off == 0, tostring(#off))
theme.flow.set_enabled(true)

print("== colored caret switch ==")
check("caret off when animated_cursor=false at setup", theme.flow.cursor_enabled() == false)
theme.flow.set_cursor(true)
check("set_cursor(true) starts it", theme.flow.cursor_enabled() == true)
theme.flow.set_cursor(false)
check("set_cursor(false) stops it", theme.flow.cursor_enabled() == false)

theme.flow.disable()
print("")
if #fails == 0 then print("ALL WORD-GRADIENT CHECKS PASSED") else print("FAILS: "..#fails); vim.cmd("cquit 1") end
