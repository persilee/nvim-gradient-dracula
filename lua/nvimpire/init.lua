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

function M.bootstrap()
	local clear = "hi clear"
	vim.api.nvim_command(clear)

	if vim.fn.exists("syntax_on") then
		local reset = "syntax reset"
		vim.api.nvim_command(reset)
	end

	vim.o.background = "dark"
	vim.o.termguicolors = true
	vim.g.colors_name = "nvimpire"
end

local commands_registered = false

local function register_commands()
	if commands_registered then return end
	commands_registered = true

	vim.api.nvim_create_user_command("NvimpireGradientFlow", function(opts)
		local scope = opts.args ~= "" and opts.args or "all"
		flow.set_scope(scope)
	end, {
		nargs = "?",
		complete = function() return { "comment", "all", "off" } end,
		desc = "Toggle nvimpire per-character flowing gradient",
	})

	vim.api.nvim_create_user_command("NvimpireGradientCursor", function(opts)
		flow.set_cursor(opts.args ~= "off")
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

function M._start_effects()
	flow.setup(config.settings, colors_mod.colors)
	register_commands()
end

function M._load()
	M.bootstrap()
	config.load_groups(groups)
	M._start_effects()
end

function M.setup(opts)
	M.bootstrap()
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
	M.bootstrap()
	config.load_groups(groups)
	M._start_effects()
end

M.flow = flow

return M
