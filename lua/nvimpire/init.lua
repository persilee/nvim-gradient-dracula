local config = require("nvimpire.config")
local colors_mod = require("nvimpire.colors")
local flow = require("nvimpire.flow")

local M = {}

M.colors = colors_mod.colors

local groups = {
	"core",
	"code",
	"lsp",
	"treesitter",
	"telescope",
	"nvim-tree",
	"neotree",
	"gitsigns",
	"cmp",
	"trouble",
	"navic",
	"mason",
	"fidget",
	"notify",
	"illuminate",
	"indent-blankline",
	"harpoon",
}

function M.bootstrap(name)
	local clear = "hi clear"
	vim.api.nvim_command(clear)

	if vim.fn.exists("syntax_on") then
		local reset = "syntax reset"
		vim.api.nvim_command(reset)
	end

	vim.o.background = "dark"
	vim.o.termguicolors = true
	vim.g.colors_name = name or "nvimpire"
end

local commands_registered = false

local function register_commands()
	if commands_registered then return end
	commands_registered = true

	vim.api.nvim_create_user_command("NvimpireGradientFlow", function(opts)
		if opts.args == "off" then
			flow.set_enabled(false)
		elseif opts.args == "on" then
			flow.set_enabled(true)
		else
			flow.toggle()
		end
	end, {
		nargs = "?",
		complete = function() return { "on", "off" } end,
		desc = "Toggle nvimpire intra-word flowing gradient",
	})

	vim.api.nvim_create_user_command("NvimpireGradientCursor", function(opts)
		if opts.args == "off" then
			flow.set_cursor(false)
		elseif opts.args == "on" then
			flow.set_cursor(true)
		else
			flow.set_cursor(not flow.cursor_enabled())
		end
	end, {
		nargs = "?",
		complete = function() return { "on", "off" } end,
		desc = "Toggle nvimpire flowing rainbow caret",
	})

	vim.api.nvim_create_user_command("NvimpireGradientStyle", function(opts)
		M.set_style(opts.args)
	end, {
		nargs = 1,
		complete = function()
			return require("nvimpire.gradient").style_names
		end,
		desc = "Switch nvimpire gradient palette",
	})
end

function M._apply_terminal_colors()
	if config.settings.terminal_colors == false then return end
	local c = colors_mod.colors
	for i = 0, 15 do
		vim.g["terminal_color_" .. i] = c["color_" .. i]
	end
end

function M._start_effects()
	M._apply_terminal_colors()
	flow.setup(config.settings, colors_mod.colors)
	register_commands()
end

function M._load(name)
	M.bootstrap(name)
	config.load_groups(groups)
	M._start_effects()
end

function M.setup(opts, name)
	M.bootstrap(name)
	config.reset()
	config.config(opts)
	config.load_groups(groups)
	M._start_effects()
end

--- Switch gradient style at runtime and re-apply the whole colorscheme.
function M.set_style(name)
	local gradient = require("nvimpire.gradient")
	if not gradient.is_valid_style(name) then
		vim.notify(
			"nvimpire: unknown style '" .. tostring(name) .. "'. Valid: "
				.. table.concat(gradient.style_names, ", "),
			vim.log.levels.ERROR
		)
		return
	end
	flow.disable()
	config.config({ style = name })
	M.bootstrap(vim.g.colors_name)
	config.load_groups(groups)
	M._start_effects()
end

M.flow = flow

return M
