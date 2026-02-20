local M = {}
local state = require("dadview.state")
local config = require("dadview.config")
local keymap = require("dadview.keymaps")
local executor = require("dadview.executor")

-- Create a new query buffer
function M.new_query_buffer()
	-- Open the buffer in a window first
	-- If DadView is open, use the main window area
	if state.state.is_open and state.state.winnr and vim.api.nvim_win_is_valid(state.state.winnr) then
		-- Find a non-DadView window
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if win ~= state.state.winnr then
				vim.api.nvim_set_current_win(win)
				break
			end
		end
	end

	-- Create a new buffer in current window
	vim.cmd("enew")
	local bufnr = vim.api.nvim_get_current_buf()

	-- Generate a unique name based on connection and timestamp
	local conn_name = state.state.current_connection and state.state.current_connection.name or "unknown"
	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = string.format("query_%s_%s.sql", conn_name, timestamp)

	-- Create directory for buffer files if it doesn't exist
	local data_dir = vim.fn.stdpath("data")
	local buffer_dir = data_dir .. "/dadbod"
	vim.fn.mkdir(buffer_dir, "p")

	-- Set buffer name with full path
	local full_path = buffer_dir .. "/" .. filename
	vim.api.nvim_buf_set_name(bufnr, full_path)

	-- Mark this as a DadView query buffer
	vim.b[bufnr].dadview_query_buffer = true

	-- Set buffer options - filetype last to trigger autocmds properly
	vim.api.nvim_buf_set_option(bufnr, "buftype", "")
	vim.api.nvim_buf_set_option(bufnr, "filetype", "sql")

	-- Set up auto-execute on save if enabled
	if config.config.auto_execute_on_save then
		local augroup = vim.api.nvim_create_augroup("DadView_" .. bufnr, { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = augroup,
			buffer = bufnr,
			callback = function()
				executor.execute_query_buffer(bufnr)
			end,
			desc = "DadView: Auto-execute query on save",
		})

		-- Show helpful message
		vim.defer_fn(function()
			if vim.api.nvim_buf_is_valid(bufnr) then
				print("DadView: Query will auto-execute on save (:w)")
			end
		end, 100)
	end

	-- Set up buffer keymaps
	keymap.setup_query_buffer_keymaps(bufnr)

	return bufnr
end

return M
