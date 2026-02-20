local M = {}
local state = require("dadview.state")
local db = require("dadview.db")
local queryBuffer = require("dadview.views.queryBuffer")

M.state = {
	connections = {},
}

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
	state.state.current_connection = connection

	print("DadView: Connected to " .. connection.name)

	-- Refresh UI if open
	if state.state.is_open then
		M.render()
	end

	-- Open new query buffer if requested (default: true)
	if opts.open_query_buffer ~= false then
		queryBuffer.new_query_buffer()
	end

	return true
end

return M
