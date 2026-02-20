local M = {}
local state = require("dadview.state")
local resultBuffer = require("dadview.views.resultBuffer")
local db = require("dadview.db")

function M.execute_query_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Check if there's a global db connection
	local db_url = vim.g.db
	if not db_url then
		print("DadView: No database connection set. Connect to a database first.")
		return
	end

	-- Check if there's already a query running for this buffer
	if state.state.active_queries[bufnr] then
		print("DadView: Query already running for this buffer. Press <C-c> to cancel.")
		return
	end

	-- Get query text - either selection or entire buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local query_text = table.concat(lines, "\n")

	if query_text:match("^%s*$") then
		print("DadView: Buffer is empty")
		return
	end

	-- Create or find result buffer
	local result_bufnr = resultBuffer.get_or_create_result_buffer(bufnr)

	-- Clear result buffer and show "Running..." message
	vim.api.nvim_buf_set_option(result_bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, {
		"-- Running query...",
		"-- Press <C-c> to cancel",
		"",
	})
	vim.api.nvim_buf_set_option(result_bufnr, "modifiable", false)

	-- Execute query
	print("DadView: Running query...")
	local start_time = vim.fn.reltime()

	local query_id = db.execute_query(db_url, {
		input = query_text,
		is_file = false,
		on_exit = function(result)
			-- Clear active query tracking
			state.state.active_queries[bufnr] = nil

			-- Calculate runtime
			local runtime = vim.fn.reltimefloat(vim.fn.reltime(start_time))

			-- Format output
			local output_lines = {}

			if result.success then
				-- Add query result
				table.insert(output_lines, string.format("-- Query completed in %.3fs", runtime))
				table.insert(output_lines, "")

				-- Add result data
				local result_lines = vim.split(result.stdout, "\n", { plain = true })
				vim.list_extend(output_lines, result_lines)

				print(string.format("DadView: Query completed in %.3fs", runtime))
			else
				-- Add error message
				table.insert(output_lines, string.format("-- Query failed after %.3fs", runtime))
				table.insert(output_lines, "")
				table.insert(output_lines, "-- ERROR:")

				local error_lines = vim.split(result.error or result.stderr or "Unknown error", "\n", { plain = true })
				for _, line in ipairs(error_lines) do
					table.insert(output_lines, "-- " .. line)
				end

				print("DadView: Query failed - see result buffer for details")
			end

			-- Update result buffer
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(result_bufnr) then
					vim.api.nvim_buf_set_option(result_bufnr, "modifiable", true)
					vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, output_lines)
					vim.api.nvim_buf_set_option(result_bufnr, "modifiable", false)
				end
			end)

			-- Store result for later access
			state.state.query_results[bufnr] = result
		end,
	})

	-- Track active query
	state.state.active_queries[bufnr] = query_id
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

return M
