local M = {}
local db = require("dadview.db")
local sidebar = require("dadview.sidebar")
local state = require("dadview.state")
local config = require("dadview.config")
local executor = require("dadview.executor")

-- Setup function for user configuration
function M.setup(opts)
	config.config = vim.tbl_deep_extend("force", config.config, opts or {})

	-- Set up global keymaps
	local keymaps_module = require("dadview.keymaps")
	keymaps_module.setup_global_keymaps()

	-- Set up autocmd to detect SQL files in the dadbod directory
	local data_dir = vim.fn.stdpath("data")
	local buffer_dir = data_dir .. "/dadbod"

	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		pattern = buffer_dir .. "/*.sql",
		callback = function(args)
			local bufnr = args.buf

			-- Mark as DadView query buffer if not already marked
			if not vim.b[bufnr].dadview_query_buffer then
				vim.b[bufnr].dadview_query_buffer = true

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
				end

				-- Set up buffer keymaps
				keymaps_module.setup_query_buffer_keymaps(bufnr)
			end
		end,
		desc = "DadView: Setup SQL files in dadbod directory",
	})
end

-- Cancel query for buffer
function M.cancel_query(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local query_id = state.state.active_queries[bufnr]
	if not query_id then
		print("DadView: No active query for this buffer")
		return
	end

	local success, err = db.cancel_query(query_id)
	if success then
		state.state.active_queries[bufnr] = nil
		print("DadView: Query cancelled")
	else
		print("DadView: Failed to cancel query: " .. (err or "unknown error"))
	end
end

-- Toggle the DB UI with optional connection name
function M.toggle(connection_name)
	sidebar.toggle(connection_name)
end

-- Cancel query for buffer
function M.cancel_query(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local query_id = state.state.active_queries[bufnr]
	if not query_id then
		print("DadView: No active query for this buffer")
		return
	end

	local success, err = db.cancel_query(query_id)
	if success then
		state.state.active_queries[bufnr] = nil
		print("DadView: Query cancelled")
	else
		print("DadView: Failed to cancel query: " .. (err or "unknown error"))
	end
end

-- Check undo history for result buffer
function M.check_undo_history()
	if not state.state.result_bufnr or not vim.api.nvim_buf_is_valid(state.state.result_bufnr) then
		print("DadView: No result buffer found")
		return
	end

	local bufnr = state.state.result_bufnr
	local undo_info = vim.fn.undotree(bufnr)

	print("=== Result Buffer Undo History ===")
	print(string.format("Buffer: %d", bufnr))
	print(string.format("Lines: %d", vim.api.nvim_buf_line_count(bufnr)))
	print(string.format("Undolevels setting: %d", vim.api.nvim_buf_get_option(bufnr, "undolevels")))

	if undo_info and undo_info.entries then
		local count = #undo_info.entries
		print(string.format("Undo states: %d", count))

		if count > 10 then
			print("⚠️  WARNING: " .. count .. " undo states detected!")
			print("Each state may hold a full copy of query results in native memory")
			print("This is likely your memory leak!")
		elseif count > 0 then
			print("Some undo states exist (may contribute to memory usage)")
		else
			print("✓ No undo states (good!)")
		end
	else
		print("✓ Undo disabled or no history")
	end
end

-- Clear undo history for result buffer
function M.clear_undo_history()
	if not state.state.result_bufnr or not vim.api.nvim_buf_is_valid(state.state.result_bufnr) then
		print("DadView: No result buffer found")
		return
	end

	local bufnr = state.state.result_bufnr
	local old_undolevels = vim.api.nvim_buf_get_option(bufnr, "undolevels")

	-- Clear undo history by setting undolevels to -1 temporarily
	vim.api.nvim_buf_set_option(bufnr, "undolevels", -1)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.cmd(string.format("buffer %d | execute 'normal! a \\<BS>\\<Esc>'", bufnr))
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

	-- Keep undo disabled
	print("DadView: Undo history cleared and disabled for result buffer")
	collectgarbage("collect")
	collectgarbage("collect")
	print("DadView: Forced garbage collection")
end

-- Placeholder functions
function M.find_buffer()
	print("DadView: Find buffer - Not yet implemented")
end

function M.rename_buffer()
	print("DadView: Rename buffer - Not yet implemented")
end

function M.last_query_info()
	print("DadView: Last query info - Not yet implemented")
end

return M
