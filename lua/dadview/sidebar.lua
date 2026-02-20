local M = {}

local connections = require("dadview.connections")
local keymaps = require("dadview.keymaps")
local config = require("dadview.config")
local state = require("dadview.state")

function M.toggle(connection_name) -- If connection name provided, just connect without toggling sidebar
	if connection_name then
		local conn = connections.find_connection(connection_name)
		if conn then
			connections.set_connection(conn, { open_query_buffer = config.config.auto_open_query_buffer })
			-- Don't toggle the sidebar when connecting directly
			return
		else
			print("DadView: Connection not found: " .. connection_name)
			return
		end
	end

	-- No connection name - just toggle the sidebar
	if state.state.is_open then
		M.close()
	else
		M.open()
	end
end

function M.open()
	if state.state.is_open then
		return
	end

	-- Create a new buffer if needed
	if not state.state.bufnr or not vim.api.nvim_buf_is_valid(state.state.bufnr) then
		state.state.bufnr = vim.api.nvim_create_buf(false, true)

		-- Set buffer options
		vim.api.nvim_buf_set_option(state.state.bufnr, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(state.state.bufnr, "filetype", "dadview")
		vim.api.nvim_buf_set_option(state.state.bufnr, "buftype", "nofile")
		vim.api.nvim_buf_set_name(state.state.bufnr, "DadView")

		-- Set initial content
		M.render()

		-- Set up keymaps
		keymaps.setup_sidebar_keymaps(state.state.bufnr)
	end

	-- Create split window
	local win_config = {
		split = config.config.position == "left" and "left" or "right",
		win = 0,
	}

	vim.cmd(config.config.width .. "vsplit")
	vim.api.nvim_win_set_buf(0, state.state.bufnr)
	state.state.winnr = vim.api.nvim_get_current_win()

	-- Set window options
	vim.api.nvim_win_set_option(state.state.winnr, "number", false)
	vim.api.nvim_win_set_option(state.state.winnr, "relativenumber", false)
	vim.api.nvim_win_set_option(state.state.winnr, "signcolumn", "no")
	vim.api.nvim_win_set_option(state.state.winnr, "wrap", false)

	state.state.is_open = true
end

function M.close()
	if not state.state.is_open then
		return
	end

	if state.state.winnr and vim.api.nvim_win_is_valid(state.state.winnr) then
		vim.api.nvim_win_close(state.state.winnr, true)
	end

	state.state.is_open = false
	state.state.winnr = nil
end

function M.render()
	if not state.state.bufnr or not vim.api.nvim_buf_is_valid(state.state.bufnr) then
		return
	end

	-- Load latest connections
	connections.load_connections()

	-- Make buffer modifiable
	vim.api.nvim_buf_set_option(state.state.bufnr, "modifiable", true)

	local lines = {
		"╔═══════════════════════════════════╗",
		"║          DadView                  ║",
		"╚═══════════════════════════════════╝",
		"",
	}

	-- Show current connection
	if state.state.current_connection then
		table.insert(lines, "[ Active Connection ]")
		table.insert(lines, "● " .. state.state.current_connection.name)
		table.insert(lines, "")
	end

	-- Show available connections
	table.insert(lines, "[ Available Connections ]")
	table.insert(lines, "")

	if #state.state.connections == 0 then
		table.insert(lines, "  -- No connections configured --")
		table.insert(lines, "  Configure via vim.g.dbs")
	else
		for i, conn in ipairs(state.state.connections) do
			local prefix = "  "
			if state.state.current_connection and conn.name == state.state.current_connection.name then
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

	vim.api.nvim_buf_set_lines(state.state.bufnr, 0, -1, false, lines)

	-- Make buffer read-only
	vim.api.nvim_buf_set_option(state.state.bufnr, "modifiable", false)
end

-- Quit the entire plugin (quit Neovim)
function M.quit_all()
	-- Clear state
	state.state.result_bufnr = nil
	state.state.result_winnr = nil

	-- Simply quit Neovim
	vim.cmd("qa")
end

-- Get connection from current line
function M.get_connection_at_cursor()
	local line = vim.api.nvim_get_current_line()

	-- Try to extract connection number (format: "  1. connection_name" or "● 1. connection_name")
	local num = line:match("^[● ]*(%d+)%.")
	if num then
		local idx = tonumber(num)
		if idx and state.state.connections[idx] then
			return state.state.connections[idx]
		end
	end

	return nil
end

-- Connect to selected database
function M.connect_at_cursor()
	local conn = M.get_connection_at_cursor()
	if conn then
		connections.set_connection(conn, { open_query_buffer = config.config.auto_open_query_buffer })
	else
		print("DadView: No connection on this line")
	end
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

return M
