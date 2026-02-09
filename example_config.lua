-- Example configuration for DadView plugin
-- Place this in your Neovim config (e.g., ~/.config/nvim/lua/plugins/dadview.lua)

return {
	"garrettkrohn/dadview",
	cmd = {
		"DadView",
		"DadViewToggle",
		"DadViewConnect",
		"DadViewClose",
		"DadViewNewQuery",
		"DadViewExecute",
		"DadViewCancel",
		"DadViewFindBuffer",
		"DadViewRenameBuffer",
		"DadViewLastQueryInfo",
		"DB",
		"DBCancel",
	},
	keys = {
		{ "<leader>dv", "<cmd>DadView<cr>", desc = "Toggle DadView" },
		{ "<leader>dq", "<cmd>DadViewNewQuery<cr>", desc = "New query buffer" },
	},

	-- Use init instead of config - init runs at startup but doesn't load the plugin
	init = function()
		-- Helper function to get passwords (replace with your password manager)
		local function pass(key)
			-- Example: return vim.fn.system('pass show ' .. key):gsub('\n', '')
			-- For now, return placeholder
			return "YOUR_PASSWORD_HERE"
		end

		-- Configure database connections (this is just setting vim.g, no plugin loading)
		vim.g.dbs = {
			{
				name = "local_db",
				url = string.format("postgresql://postgres:%s@localhost:5432/mydb", "postgres"),
			},
			{
				name = "dev_db",
				url = string.format("postgresql://username:%s@localhost:5432/mydb", pass("dev")),
			},
			{
				name = "staging_db",
				url = string.format("postgresql://username:%s@staging-host:5432/mydb", pass("staging")),
			},
			{
				name = "prod_db",
				url = string.format("postgresql://username:%s@prod-host:5432/mydb", pass("prod")),
			},
		}
	end,

	-- Config runs AFTER the plugin is loaded (when a command/key is triggered)
	config = function()
		-- Setup DadView with your preferences
		require("dadview").setup({
			width = 40,
			position = "left",
			auto_open_query_buffer = true, -- Automatically open query buffer on connect
			auto_execute_on_save = true, -- Automatically execute query on save
		})
	end,
}
