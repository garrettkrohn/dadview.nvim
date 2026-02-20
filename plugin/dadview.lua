local data_dir = vim.fn.stdpath("data")
local buffer_dir = data_dir .. "/dadbod"

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = buffer_dir .. "/*.sql",
	callback = function(args)
		local bufnr = args.buf

		if not vim.b[bufnr].dadview_query_buffer then
			vim.b[bufnr].dadview_query_buffer = true

			local config = require("dadview.config")
			if config.config.auto_execute_on_save then
				local augroup = vim.api.nvim_create_augroup("DadView_" .. bufnr, { clear = true })
				vim.api.nvim_create_autocmd("BufWritePost", {
					group = augroup,
					buffer = bufnr,
					callback = function()
						local executor = require("dadview.executor")
						executor.execute_query_buffer(bufnr)
					end,
					desc = "DadView: Auto-execute query on save",
				})
			end

			local keymaps_module = require("dadview.keymaps")
			keymaps_module.setup_query_buffer_keymaps(bufnr)
		end
	end,
	desc = "DadView: Setup SQL files in dadbod directory",
})
