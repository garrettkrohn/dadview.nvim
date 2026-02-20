local M = {}
local state = require("dadview.state")

-- Get or create result buffer (shared across all query buffers)
function M.get_or_create_result_buffer(query_bufnr)
	-- Check if shared result buffer already exists and is valid
	if state.state.result_bufnr and vim.api.nvim_buf_is_valid(state.state.result_bufnr) then
		-- Buffer exists, check if window is still open
		if state.state.result_winnr and vim.api.nvim_win_is_valid(state.state.result_winnr) then
			-- Window exists, just return the buffer
			return state.state.result_bufnr
		else
			-- Window was closed, reopen it
			local current_win = vim.api.nvim_get_current_win()
			vim.cmd("belowright split")
			vim.api.nvim_win_set_buf(0, state.state.result_bufnr)
			state.state.result_winnr = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(current_win)
			return state.state.result_bufnr
		end
	end

	-- Create new shared result buffer
	local result_bufnr = vim.api.nvim_create_buf(false, true)
	state.state.result_bufnr = result_bufnr

	-- Set buffer options
	vim.api.nvim_buf_set_option(result_bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(result_bufnr, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(result_bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(result_bufnr, "filetype", "dbout")
	vim.api.nvim_buf_set_option(result_bufnr, "modifiable", false)

	-- CRITICAL: Disable undo history to prevent memory leak
	-- Each query result creates a new undo state, holding entire buffer in native memory
	vim.api.nvim_buf_set_option(result_bufnr, "undolevels", -1)

	-- Set buffer name
	vim.api.nvim_buf_set_name(result_bufnr, "DadView Results")

	-- Mark as DadView result buffer
	vim.b[result_bufnr].dadview_result_buffer = true

	-- Set up keymaps for result buffer
	local keymaps = require("dadview.keymaps")
	keymaps.setup_result_buffer_keymaps(result_bufnr)

	-- Open result buffer in a split
	local current_win = vim.api.nvim_get_current_win()
	vim.cmd("belowright split")
	vim.api.nvim_win_set_buf(0, result_bufnr)
	state.state.result_winnr = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(current_win)

	return result_bufnr
end

return M
