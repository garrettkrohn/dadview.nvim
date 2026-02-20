local M = {}

-- Set up keymaps for query buffers
function M.setup_query_buffer_keymaps(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }

	-- Execute with <leader>r or <C-CR>
	vim.keymap.set("n", "<leader>r", function()
		M.execute_query_buffer(bufnr)
	end, vim.tbl_extend("force", opts, { desc = "Execute query" }))
	vim.keymap.set("n", "<C-CR>", function()
		M.execute_query_buffer(bufnr)
	end, vim.tbl_extend("force", opts, { desc = "Execute query" }))

	-- Cancel query with <C-c>
	vim.keymap.set("n", "<C-c>", function()
		M.cancel_query(bufnr)
	end, vim.tbl_extend("force", opts, { desc = "Cancel query" }))

	-- Quit all with q
	vim.keymap.set("n", "q", function()
		M.quit_all()
	end, vim.tbl_extend("force", opts, { desc = "Quit DadView" }))

	-- Navigate to next | with C-n
	vim.keymap.set("n", "<C-n>", function()
		vim.fn.search("|", "W")
	end, vim.tbl_extend("force", opts, { desc = "Go to next |" }))

	-- Navigate to previous | with C-p
	vim.keymap.set("n", "<C-p>", function()
		vim.fn.search("|", "bW")
	end, vim.tbl_extend("force", opts, { desc = "Go to previous |" }))

	-- TODO: Execute selection in visual mode
	-- vim.keymap.set('v', '<leader>r', function() M.execute_selection() end,
	--   vim.tbl_extend('force', opts, { desc = 'Execute selection' }))
end

-- Set up buffer keymaps
function M.setup_keymaps()
	-- if not M.state.bufnr then
	-- 	return
	-- end

	local opts = {
		noremap = true,
		silent = true,
		-- buffer = M.state.bufnr
	}

	-- Quit all with q
	vim.keymap.set("n", "q", function()
		M.quit_all()
	end, opts)

	-- Refresh with R
	vim.keymap.set("n", "R", function()
		M.render()
	end, opts)

	-- Help with ?
	vim.keymap.set("n", "?", function()
		M.show_help()
	end, opts)

	-- Connect with Enter
	vim.keymap.set("n", "<CR>", function()
		M.connect_at_cursor()
	end, opts)
end

return M
