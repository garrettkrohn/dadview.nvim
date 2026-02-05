local M = {}
local db = require("dadview.db")

-- State management
M.state = {
	is_open = false,
	bufnr = nil,
	winnr = nil,
	current_connection = nil,
	connections = {},
	query_results = {}, -- Store query results by buffer
	active_queries = {}, -- Track running queries by buffer
	result_bufnr = nil, -- Single shared result buffer
	result_winnr = nil, -- Window showing the result buffer
}

-- Configuration
M.config = {
	width = 40,
	position = "left", -- 'left' or 'right'
	auto_open_query_buffer = true, -- Automatically open query buffer on connect
	auto_execute_on_save = true, -- Automatically execute query on save
}

-- Setup function for user configuration
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	
	-- Set up autocmd to detect SQL files in the dadbod directory
	local data_dir = vim.fn.stdpath("data")
	local buffer_dir = data_dir .. "/dadbod"
	
	vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
		pattern = buffer_dir .. "/*.sql",
		callback = function(args)
			local bufnr = args.buf
			
			-- Mark as DadView query buffer if not already marked
			if not vim.b[bufnr].dadview_query_buffer then
				vim.b[bufnr].dadview_query_buffer = true
				
				-- Set up auto-execute on save if enabled
				if M.config.auto_execute_on_save then
					local augroup = vim.api.nvim_create_augroup("DadView_" .. bufnr, { clear = true })
					vim.api.nvim_create_autocmd("BufWritePost", {
						group = augroup,
						buffer = bufnr,
						callback = function()
							M.execute_query_buffer(bufnr)
						end,
						desc = "DadView: Auto-execute query on save",
					})
				end
				
				-- Set up buffer keymaps
				M.setup_query_buffer_keymaps(bufnr)
			end
		end,
		desc = "DadView: Setup SQL files in dadbod directory",
	})
end

-- Load connections from vim.g.dbs
function M.load_connections()
	local dbs = vim.g.dbs
	if not dbs or type(dbs) ~= "table" then
		M.state.connections = {}
		return
	end

	M.state.connections = dbs
end

-- Find connection by name (supports partial matching)
function M.find_connection(pattern)
	M.load_connections()

	if not pattern or pattern == "" then
		return nil
	end

	-- First try exact match
	for _, conn in ipairs(M.state.connections) do
		if conn.name == pattern then
			return conn
		end
	end

	-- Then try partial match (case insensitive)
	local pattern_lower = pattern:lower()
	for _, conn in ipairs(M.state.connections) do
		if conn.name:lower():match(pattern_lower) then
			return conn
		end
	end

	return nil
end

-- Execute query buffer
function M.execute_query_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Check if there's a global db connection
	local db_url = vim.g.db
	if not db_url then
		print("DadView: No database connection set. Connect to a database first.")
		return
	end

	-- Check if there's already a query running for this buffer
	if M.state.active_queries[bufnr] then
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
	local result_bufnr = M.get_or_create_result_buffer(bufnr)

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
			M.state.active_queries[bufnr] = nil

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
			M.state.query_results[bufnr] = result
		end,
	})

	-- Track active query
	M.state.active_queries[bufnr] = query_id
end

-- Create a new query buffer
function M.new_query_buffer()
	-- Open the buffer in a window first
	-- If DadView is open, use the main window area
	if M.state.is_open and M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
		-- Find a non-DadView window
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if win ~= M.state.winnr then
				vim.api.nvim_set_current_win(win)
				break
			end
		end
	end

	-- Create a new buffer in current window
	vim.cmd("enew")
	local bufnr = vim.api.nvim_get_current_buf()

	-- Generate a unique name based on connection and timestamp
	local conn_name = M.state.current_connection and M.state.current_connection.name or "unknown"
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
	if M.config.auto_execute_on_save then
		local augroup = vim.api.nvim_create_augroup("DadView_" .. bufnr, { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = augroup,
			buffer = bufnr,
			callback = function()
				M.execute_query_buffer(bufnr)
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
	M.setup_query_buffer_keymaps(bufnr)

	return bufnr
end

-- Get or create result buffer (shared across all query buffers)
function M.get_or_create_result_buffer(query_bufnr)
	-- Check if shared result buffer already exists and is valid
	if M.state.result_bufnr and vim.api.nvim_buf_is_valid(M.state.result_bufnr) then
		-- Buffer exists, check if window is still open
		if M.state.result_winnr and vim.api.nvim_win_is_valid(M.state.result_winnr) then
			-- Window exists, just return the buffer
			return M.state.result_bufnr
		else
			-- Window was closed, reopen it
			local current_win = vim.api.nvim_get_current_win()
			vim.cmd("belowright split")
			vim.api.nvim_win_set_buf(0, M.state.result_bufnr)
			M.state.result_winnr = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(current_win)
			return M.state.result_bufnr
		end
	end

	-- Create new shared result buffer
	local result_bufnr = vim.api.nvim_create_buf(false, true)
	M.state.result_bufnr = result_bufnr

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
	local result_opts = { noremap = true, silent = true, buffer = result_bufnr }
	vim.keymap.set("n", "q", function()
		M.quit_all()
	end, vim.tbl_extend("force", result_opts, { desc = "Quit DadView" }))

	-- Navigate to next | with C-n
	vim.keymap.set("n", "<C-n>", function()
		vim.fn.search("|", "W")
	end, vim.tbl_extend("force", result_opts, { desc = "Go to next |" }))

	-- Navigate to previous | with C-p
	vim.keymap.set("n", "<C-p>", function()
		vim.fn.search("|", "bW")
	end, vim.tbl_extend("force", result_opts, { desc = "Go to previous |" }))

	-- Open result buffer in a split
	local current_win = vim.api.nvim_get_current_win()
	vim.cmd("belowright split")
	vim.api.nvim_win_set_buf(0, result_bufnr)
	M.state.result_winnr = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(current_win)

	return result_bufnr
end

-- Cancel query for buffer
function M.cancel_query(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local query_id = M.state.active_queries[bufnr]
	if not query_id then
		print("DadView: No active query for this buffer")
		return
	end

	local success, err = db.cancel_query(query_id)
	if success then
		M.state.active_queries[bufnr] = nil
		print("DadView: Query cancelled")
	else
		print("DadView: Failed to cancel query: " .. (err or "unknown error"))
	end
end

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

-- Set the active database connection
function M.set_connection(connection, opts)
	opts = opts or {}

	if not connection then
		print("DadView: No connection provided")
		return false
	end

	if not connection.url then
		print("DadView: Connection missing URL: " .. (connection.name or "unknown"))
		return false
	end

	-- Test connection first
	local success, err = db.test_connection(connection.url)
	if not success then
		print("DadView: Failed to connect to " .. connection.name .. ": " .. (err or "unknown error"))
		return false
	end

	-- Set global db for current connection
	vim.g.db = connection.url
	M.state.current_connection = connection

	print("DadView: Connected to " .. connection.name)

	-- Refresh UI if open
	if M.state.is_open then
		M.render()
	end

	-- Open new query buffer if requested (default: true)
	if opts.open_query_buffer ~= false then
		M.new_query_buffer()
	end

	return true
end

-- Toggle the DB UI with optional connection name
function M.toggle(connection_name)
	-- If connection name provided, just connect without toggling sidebar
	if connection_name then
		local conn = M.find_connection(connection_name)
		if conn then
			M.set_connection(conn, { open_query_buffer = M.config.auto_open_query_buffer })
			-- Don't toggle the sidebar when connecting directly
			return
		else
			print("DadView: Connection not found: " .. connection_name)
			return
		end
	end

	-- No connection name - just toggle the sidebar
	if M.state.is_open then
		M.close()
	else
		M.open()
	end
end

-- Open the DB UI
function M.open()
	if M.state.is_open then
		return
	end

	-- Create a new buffer if needed
	if not M.state.bufnr or not vim.api.nvim_buf_is_valid(M.state.bufnr) then
		M.state.bufnr = vim.api.nvim_create_buf(false, true)

		-- Set buffer options
		vim.api.nvim_buf_set_option(M.state.bufnr, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(M.state.bufnr, "filetype", "dadview")
		vim.api.nvim_buf_set_option(M.state.bufnr, "buftype", "nofile")
		vim.api.nvim_buf_set_name(M.state.bufnr, "DadView")

		-- Set initial content
		M.render()

		-- Set up keymaps
		M.setup_keymaps()
	end

	-- Create split window
	local win_config = {
		split = M.config.position == "left" and "left" or "right",
		win = 0,
	}

	vim.cmd(M.config.width .. "vsplit")
	vim.api.nvim_win_set_buf(0, M.state.bufnr)
	M.state.winnr = vim.api.nvim_get_current_win()

	-- Set window options
	vim.api.nvim_win_set_option(M.state.winnr, "number", false)
	vim.api.nvim_win_set_option(M.state.winnr, "relativenumber", false)
	vim.api.nvim_win_set_option(M.state.winnr, "signcolumn", "no")
	vim.api.nvim_win_set_option(M.state.winnr, "wrap", false)

	M.state.is_open = true
end

-- Close the DB UI
function M.close()
	if not M.state.is_open then
		return
	end

	if M.state.winnr and vim.api.nvim_win_is_valid(M.state.winnr) then
		vim.api.nvim_win_close(M.state.winnr, true)
	end

	M.state.is_open = false
	M.state.winnr = nil
end

-- Quit the entire plugin (quit Neovim)
function M.quit_all()
	-- Clear state
	M.state.result_bufnr = nil
	M.state.result_winnr = nil
	
	-- Simply quit Neovim
	vim.cmd("qa")
end

-- Render the UI content
function M.render()
	if not M.state.bufnr or not vim.api.nvim_buf_is_valid(M.state.bufnr) then
		return
	end

	-- Load latest connections
	M.load_connections()

	-- Make buffer modifiable
	vim.api.nvim_buf_set_option(M.state.bufnr, "modifiable", true)

	local lines = {
		"╔═══════════════════════════════════╗",
		"║          DadView                  ║",
		"╚═══════════════════════════════════╝",
		"",
	}

	-- Show current connection
	if M.state.current_connection then
		table.insert(lines, "[ Active Connection ]")
		table.insert(lines, "● " .. M.state.current_connection.name)
		table.insert(lines, "")
	end

	-- Show available connections
	table.insert(lines, "[ Available Connections ]")
	table.insert(lines, "")

	if #M.state.connections == 0 then
		table.insert(lines, "  -- No connections configured --")
		table.insert(lines, "  Configure via vim.g.dbs")
	else
		for i, conn in ipairs(M.state.connections) do
			local prefix = "  "
			if M.state.current_connection and conn.name == M.state.current_connection.name then
				prefix = "● "
			end
			table.insert(lines, prefix .. i .. ". " .. conn.name)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "[ Actions ]")
	table.insert(lines, "  <CR> - Connect to selection")
	table.insert(lines, "  R    - Refresh")
	table.insert(lines, "  ?    - Help")
	table.insert(lines, "  q    - Close")

	vim.api.nvim_buf_set_lines(M.state.bufnr, 0, -1, false, lines)

	-- Make buffer read-only
	vim.api.nvim_buf_set_option(M.state.bufnr, "modifiable", false)
end

-- Get connection from current line
function M.get_connection_at_cursor()
	local line = vim.api.nvim_get_current_line()

	-- Try to extract connection number (format: "  1. connection_name" or "● 1. connection_name")
	local num = line:match("^[● ]*(%d+)%.")
	if num then
		local idx = tonumber(num)
		if idx and M.state.connections[idx] then
			return M.state.connections[idx]
		end
	end

	return nil
end

-- Connect to selected database
function M.connect_at_cursor()
	local conn = M.get_connection_at_cursor()
	if conn then
		M.set_connection(conn, { open_query_buffer = M.config.auto_open_query_buffer })
	else
		print("DadView: No connection on this line")
	end
end

-- Set up buffer keymaps
function M.setup_keymaps()
	if not M.state.bufnr then
		return
	end

	local opts = { noremap = true, silent = true, buffer = M.state.bufnr }

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

-- Show help
function M.show_help()
	local help_lines = {
		"DadView - Help",
		"",
		"Keymaps:",
		"  <CR> - Connect to database under cursor",
		"  q    - Close DadView",
		"  R    - Refresh connection list",
		"  ?    - Show this help",
		"",
		"Commands:",
		"  :DadView [connection]",
		"      Toggle UI, optionally connect to named connection",
		"  :DadViewConnect <connection>",
		"      Connect to a database by name",
		"",
		"Configuration:",
		"  Set vim.g.dbs to a list of connections:",
		"  vim.g.dbs = {",
		'    { name = "local", url = "postgresql://..." },',
		'    { name = "dev", url = "postgresql://..." },',
		"  }",
		"",
		"Press <Esc> to close...",
	}

	-- Create floating window for help
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	local width = 60
	local height = #help_lines
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
	})

	-- Close on Esc or q
	local close_opts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "<esc>", function()
		vim.api.nvim_win_close(win, true)
	end, close_opts)
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, close_opts)
end

-- Check undo history for result buffer
function M.check_undo_history()
	if not M.state.result_bufnr or not vim.api.nvim_buf_is_valid(M.state.result_bufnr) then
		print("DadView: No result buffer found")
		return
	end
	
	local bufnr = M.state.result_bufnr
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
	if not M.state.result_bufnr or not vim.api.nvim_buf_is_valid(M.state.result_bufnr) then
		print("DadView: No result buffer found")
		return
	end
	
	local bufnr = M.state.result_bufnr
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
