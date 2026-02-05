local M = {}
local adapters = require("dadview.adapters")

-- Track if adapters have been loaded
local adapters_loaded = false

-- Load and register adapters
local function load_adapters()
	if adapters_loaded then
		return
	end
	
	-- Register PostgreSQL adapter
	local postgresql = require("dadview.adapters.postgresql")
	adapters.register("postgresql", postgresql)
	adapters.register("postgres", postgresql) -- Alias
	
	adapters_loaded = true
end

-- Active queries registry (for cancellation)
M.active_queries = {}

-- Query counter for unique IDs
local query_counter = 0

-- Execute a query asynchronously
-- @param url string: Database connection URL
-- @param opts table: Options
--   - input: string (query text) or file path
--   - is_file: boolean (true if input is a file path)
--   - on_stdout: function(data) (optional callback for streaming output)
--   - on_stderr: function(data) (optional callback for errors)
--   - on_exit: function(result) (callback when done)
-- @return number: query_id for tracking/cancellation
function M.execute_query(url, opts)
	load_adapters() -- Ensure adapters are loaded
	
	opts = opts or {}

	query_counter = query_counter + 1
	local query_id = query_counter

	-- Parse URL and build command
	local cmd, env
	local temp_file = nil -- Track temp file for cleanup
	
	if opts.is_file then
		cmd, env = adapters.build_command(url, { file = opts.input })
	else
		-- Write query to temp file
		temp_file = vim.fn.tempname() .. ".sql"
		local file = io.open(temp_file, "w")
		if file then
			file:write(opts.input)
			file:close()
		else
			if opts.on_exit then
				opts.on_exit({
					success = false,
					error = "Failed to create temp file",
				})
			end
			return query_id
		end

		cmd, env = adapters.build_command(url, { file = temp_file })
	end

	if not cmd then
		if opts.on_exit then
			opts.on_exit({
				success = false,
				error = env or "Failed to build command",
			})
		end
		return query_id
	end

	-- Track start time
	local start_time = vim.loop.hrtime()

	-- Execute command
	local stdout_chunks = {}
	local stderr_chunks = {}

	local job = vim.system(cmd, {
		env = env,
		text = true,
		stdout = function(err, data)
			if data then
				table.insert(stdout_chunks, data)
				if opts.on_stdout then
					opts.on_stdout(data)
				end
			end
		end,
		stderr = function(err, data)
			if data then
				table.insert(stderr_chunks, data)
				if opts.on_stderr then
					opts.on_stderr(data)
				end
			end
		end,
	}, function(result)
		-- Clean up from active queries
		M.active_queries[query_id] = nil
		
		-- Clean up temp file if we created one
		if temp_file then
			vim.schedule(function()
				vim.fn.delete(temp_file)
			end)
		end

		-- Calculate runtime
		local end_time = vim.loop.hrtime()
		local runtime_ms = (end_time - start_time) / 1000000

		-- Combine output
		local stdout = table.concat(stdout_chunks, "")
		local stderr = table.concat(stderr_chunks, "")

		-- Format results
		local formatted_output = stdout
		if result.code == 0 and #stdout > 0 then
			formatted_output = adapters.format_results(url, stdout, {})
		end

		-- Build result object
		local query_result = {
			success = result.code == 0,
			exit_code = result.code,
			stdout = formatted_output,
			stderr = stderr,
			runtime_ms = runtime_ms,
			query_id = query_id,
		}

		if result.code ~= 0 then
			query_result.error = stderr ~= "" and stderr or "Query failed"
		end

		-- Call completion callback
		if opts.on_exit then
			vim.schedule(function()
				opts.on_exit(query_result)
			end)
		end
	end)

	-- Store job for potential cancellation
	M.active_queries[query_id] = {
		job = job,
		url = url,
		start_time = start_time,
	}

	return query_id
end

-- Cancel a running query
function M.cancel_query(query_id)
	local query = M.active_queries[query_id]
	if not query then
		return false, "Query not found or already completed"
	end

	if query.job then
		query.job:kill(15) -- SIGTERM
	end

	M.active_queries[query_id] = nil
	return true
end

-- Cancel all running queries (emergency cleanup)
function M.cancel_all_queries()
	local count = 0
	for query_id, query in pairs(M.active_queries) do
		if query.job then
			pcall(function()
				query.job:kill(15) -- SIGTERM
			end)
		end
		M.active_queries[query_id] = nil
		count = count + 1
	end
	return count
end

-- Test database connection
function M.test_connection(url)
	load_adapters() -- Ensure adapters are loaded
	return adapters.test_connection(url)
end

-- Parse database URL
function M.parse_url(url)
	load_adapters() -- Ensure adapters are loaded
	return adapters.parse_url(url)
end

-- Get list of tables (if adapter supports it)
function M.get_tables(url)
	load_adapters() -- Ensure adapters are loaded
	local adapter, err = adapters.get_adapter(url)
	if not adapter then
		return nil, err
	end

	if not adapter.get_tables then
		return nil, "Adapter does not support listing tables"
	end

	local parsed, parse_err = adapter.parse_url(url)
	if not parsed then
		return nil, parse_err
	end

	return adapter.get_tables(parsed)
end

-- Get available database adapters
function M.available_adapters()
	load_adapters() -- Ensure adapters are loaded
	return adapters.available_adapters()
end

-- Execute query synchronously (blocking)
-- Mainly for testing or simple use cases
function M.execute_query_sync(url, query)
	load_adapters() -- Ensure adapters are loaded
	
	local cmd, env

	-- Write query to temp file
	local temp_file = vim.fn.tempname() .. ".sql"
	local file = io.open(temp_file, "w")
	if not file then
		return nil, "Failed to create temp file"
	end
	file:write(query)
	file:close()

	cmd, env = adapters.build_command(url, { file = temp_file })
	if not cmd then
		return nil, env or "Failed to build command"
	end

	local result = vim.system(cmd, {
		env = env,
		text = true,
	}):wait()

	-- Clean up temp file
	vim.fn.delete(temp_file)

	if result.code == 0 then
		return adapters.format_results(url, result.stdout, {})
	else
		return nil, result.stderr or "Query failed"
	end
end

return M
