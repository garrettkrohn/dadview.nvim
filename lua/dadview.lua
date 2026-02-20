local M = {}
local config = require("dadview.config")

function M.setup(opts)
	config.config = vim.tbl_deep_extend("force", config.config, opts or {})

	-- Set up global keymaps
	local keymaps_module = require("dadview.keymaps")
	keymaps_module.setup_global_keymaps()
end

return M
