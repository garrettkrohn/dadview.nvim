local M = {}
local state = require("dadview.state")
local config = require("dadview.config")

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
			local split_cmd = config.config.result_split == "vertical" and "belowright vsplit" or "belowright split"
			vim.cmd(split_cmd)
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
	local split_cmd = config.config.result_split == "vertical" and "belowright vsplit" or "belowright split"
	vim.cmd(split_cmd)
	vim.api.nvim_win_set_buf(0, result_bufnr)
	state.state.result_winnr = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(current_win)

	return result_bufnr
end

-- Toggle result buffer between vertical and horizontal split
function M.toggle_split_direction()
	if not state.state.result_winnr or not vim.api.nvim_win_is_valid(state.state.result_winnr) then
		vim.notify("No result window open", vim.log.levels.WARN)
		return
	end

	-- Switch to result window
	local previous_win = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(state.state.result_winnr)
	
	-- Use Ctrl-w L for vertical (move to right) or Ctrl-w J for horizontal (move to bottom)
	-- Check current layout to determine which direction to move
	local win_width = vim.api.nvim_win_get_width(state.state.result_winnr)
	local win_height = vim.api.nvim_win_get_height(state.state.result_winnr)
	local total_width = vim.o.columns
	local total_height = vim.o.lines
	
	-- If window is roughly full width, it's horizontal - move to vertical (right)
	-- If window is partial width, it's vertical - move to horizontal (bottom)
	if win_width > (total_width * 0.7) then
		vim.cmd("wincmd L")
	else
		vim.cmd("wincmd J")
	end
	
	-- Return to previous window
	if vim.api.nvim_win_is_valid(previous_win) then
		vim.api.nvim_set_current_win(previous_win)
	end
end

return M
