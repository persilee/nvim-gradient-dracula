-- Reproduces the lazy.nvim opts->setup path.
-- Run: nvim --headless -u NONE --cmd "set rtp+=." -c "luafile test/lazy_path_spec.lua" -c "qa!"
for _, p in ipairs(vim.api.nvim_get_runtime_file("lua", true)) do
  package.path = p .. "/?.lua;" .. p .. "/?/init.lua;" .. package.path
end

local fails = {}
local function ok(name, cond, extra)
  if cond then print("  [PASS] "..name) else fails[#fails+1]=name; print("  [FAIL] "..name.." "..tostring(extra)) end
end

print("== facades resolve lazy main inference ==")
local by_repo = require("nvim-gradient-dracula")
local by_name = require("gradient_dracula")
local core = require("nvimpire")
ok("require('nvim-gradient-dracula') returns theme module", type(by_repo.setup)=="function")
ok("require('gradient_dracula') returns theme module", type(by_name.setup)=="function")
ok("facades are the same module", by_repo==core and by_name==core)

print("== user option aliases accepted ==")
by_name.setup({
  transparent_bg = true, style = "dracula", terminal_colors = true,
  italic_comment = true, cursor_color = false,
  flow = { enabled = true, scope = "comment" },
})
local cfg = require("nvimpire.config")
ok("transparent_bg -> transparent", cfg.settings.transparent == true)
ok("italic_comment -> italic_comments", cfg.settings.italic_comments == true)
ok("terminal_colors kept", cfg.settings.terminal_colors == true)
ok("cursor_color -> animated_cursor", cfg.settings.animated_cursor == false)
ok("flow.scope kept", cfg.settings.flow.scope == "comment")
ok("alias keys removed", cfg.settings.transparent_bg == nil and cfg.settings.italic_comment == nil
  and cfg.settings.cursor_color == nil)

print("== terminal colors applied ==")
local c = require("nvimpire.colors").colors
local tc_ok = true
for i=0,15 do if vim.g["terminal_color_"..i] ~= c["color_"..i] then tc_ok=false end end
ok("g:terminal_color_0..15 match palette", tc_ok)

print("== colorscheme aliases load ==")
ok("colorscheme nvim-gradient-dracula",
  pcall(vim.cmd.colorscheme, "nvim-gradient-dracula") and vim.g.colors_name=="nvim-gradient-dracula", vim.g.colors_name)
ok("colorscheme gradient_dracula",
  pcall(vim.cmd.colorscheme, "gradient_dracula") and vim.g.colors_name=="gradient_dracula", vim.g.colors_name)
ok("original colorscheme nvimpire still works",
  pcall(vim.cmd.colorscheme, "nvimpire") and vim.g.colors_name=="nvimpire")

print("== transparent honored through alias ==")
local normal = vim.api.nvim_get_hl(0,{name="Normal",link=false})
ok("Normal bg cleared when transparent_bg=true", normal.bg == nil, tostring(normal.bg))

core.flow.disable()
print("")
if #fails==0 then print("ALL LAZY-PATH CHECKS PASSED") else print("FAILS: "..#fails); vim.cmd("cquit 1") end
