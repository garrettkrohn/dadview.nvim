-- Memory debugging utilities for DadView
local M = {}

-- Track memory snapshots over time
M.snapshots = {}
M.snapshot_count = 0

-- Take a detailed memory snapshot
function M.take_snapshot(label)
	M.snapshot_count = M.snapshot_count + 1
	
	-- Force GC before measuring
	collectgarbage("collect")
	collectgarbage("collect")
	
	local snapshot = {
		id = M.snapshot_count,
		label = label or "snapshot_" .. M.snapshot_count,
		timestamp = os.time(),
		
		-- Lua memory
		lua_memory_kb = collectgarbage("count"),
		
		-- Process memory (RSS)
		rss_kb = 0,
		
		-- Buffer counts
		total_buffers = 0,
		loaded_buffers = 0,
		dadview_query_buffers = 0,
		dadview_result_buffers = 0,
		
		-- Buffer sizes
		total_buffer_lines = 0,
		result_buffer_lines = 0,
		
		-- Temp files
		temp_sql_files = 0,
	}
	
	-- Get RSS
	local handle = io.popen(string.format("ps -o rss= -p %d 2>/dev/null", vim.fn.getpid()))
	if handle then
		local rss = handle:read("*a")
		handle:close()
		snapshot.rss_kb = tonumber(rss) or 0
	end
	
	-- Count buffers
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			snapshot.total_buffers = snapshot.total_buffers + 1
			
			if vim.api.nvim_buf_is_loaded(bufnr) then
				snapshot.loaded_buffers = snapshot.loaded_buffers + 1
				local lines = vim.api.nvim_buf_line_count(bufnr)
				snapshot.total_buffer_lines = snapshot.total_buffer_lines + lines
				
				if vim.b[bufnr].dadview_query_buffer then
					snapshot.dadview_query_buffers = snapshot.dadview_query_buffers + 1
				elseif vim.b[bufnr].dadview_result_buffer then
					snapshot.dadview_result_buffers = snapshot.dadview_result_buffers + 1
					snapshot.result_buffer_lines = lines
				end
			end
		end
	end
	
	-- Count temp SQL files
	local temp_dir = vim.fn.tempname():match("(.*/)")
	if temp_dir then
		local temp_handle = io.popen(string.format("find '%s' -name '*.sql' -type f 2>/dev/null | wc -l", temp_dir:gsub("'", "'\\''")))
		if temp_handle then
			local count = temp_handle:read("*a")
			temp_handle:close()
			snapshot.temp_sql_files = tonumber(count) or 0
		end
	end
	
	table.insert(M.snapshots, snapshot)
	
	-- CRITICAL: Limit snapshot history to prevent memory leak
	-- Keep only last 50 snapshots
	if #M.snapshots > 50 then
		table.remove(M.snapshots, 1)
		print(string.format("⚠️  Snapshot limit reached (%d). Removed oldest snapshot.", #M.snapshots))
	end
	
	return snapshot
end

-- Compare two snapshots
function M.compare(id1, id2)
	local s1 = M.snapshots[id1]
	local s2 = M.snapshots[id2 or #M.snapshots]
	
	if not s1 or not s2 then
		print("Error: Invalid snapshot IDs")
		return
	end
	
	print(string.format("=== Comparing Snapshot #%d (%s) vs #%d (%s) ===", 
		s1.id, s1.label, s2.id, s2.label))
	print("")
	
	local function delta(val1, val2, unit, threshold)
		local diff = val2 - val1
		local sign = diff >= 0 and "+" or ""
		local warning = math.abs(diff) > threshold and " ⚠️" or ""
		return string.format("%s%d %s%s", sign, diff, unit, warning)
	end
	
	print(string.format("Lua Memory:        %d KB → %d KB (%s)", 
		s1.lua_memory_kb, s2.lua_memory_kb, delta(s1.lua_memory_kb, s2.lua_memory_kb, "KB", 10240)))
	
	print(string.format("Process Memory:    %.1f MB → %.1f MB (%s)", 
		s1.rss_kb/1024, s2.rss_kb/1024, delta(s1.rss_kb/1024, s2.rss_kb/1024, "MB", 100)))
	
	print(string.format("Total Buffers:     %d → %d (%s)", 
		s1.total_buffers, s2.total_buffers, delta(s1.total_buffers, s2.total_buffers, "", 5)))
	
	print(string.format("Loaded Buffers:    %d → %d (%s)", 
		s1.loaded_buffers, s2.loaded_buffers, delta(s1.loaded_buffers, s2.loaded_buffers, "", 5)))
	
	print(string.format("Query Buffers:     %d → %d (%s)", 
		s1.dadview_query_buffers, s2.dadview_query_buffers, delta(s1.dadview_query_buffers, s2.dadview_query_buffers, "", 3)))
	
	print(string.format("Result Buf Lines:  %d → %d (%s)", 
		s1.result_buffer_lines, s2.result_buffer_lines, delta(s1.result_buffer_lines, s2.result_buffer_lines, "", 10000)))
	
	print(string.format("Temp SQL Files:    %d → %d (%s)", 
		s1.temp_sql_files, s2.temp_sql_files, delta(s1.temp_sql_files, s2.temp_sql_files, "", 2)))
	
	print("")
	print("Duration: " .. (s2.timestamp - s1.timestamp) .. " seconds")
end

-- Show all snapshots
function M.list_snapshots()
	print("=== Memory Snapshots ===")
	print("")
	for i, snap in ipairs(M.snapshots) do
		print(string.format("#%d: %s (%.1f MB, %d buffers)", 
			snap.id, snap.label, snap.rss_kb/1024, snap.total_buffers))
	end
	print("")
	print("Use :lua require('dadview.debug_memory').compare(1, 2) to compare")
end

-- Clear snapshots
function M.clear_snapshots()
	M.snapshots = {}
	M.snapshot_count = 0
	print("Cleared all memory snapshots")
end

-- Automated leak detection: take snapshots and watch for growth
function M.start_leak_detection(interval)
	interval = interval or 3  -- seconds
	
	local dadview = require("dadview")
	
	-- Check if timer already running
	if dadview.state.memory_monitor_timer then
		print("⚠️  WARNING: A memory monitor is already running!")
		print("Stop it first with :DadViewStopMemoryMonitor")
		return
	end
	
	print("=== Starting Leak Detection ===")
	print(string.format("Taking snapshot every %d seconds", interval))
	print("⚠️  WARNING: This reads ALL buffer contents and can cause memory growth!")
	print("Perform actions in DadView, then stop with :DadViewStopMemoryMonitor")
	print("")
	
	-- Take initial snapshot
	M.take_snapshot("baseline")
	
	-- Track buffer creation
	local last_buffer_list = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			last_buffer_list[bufnr] = true
		end
	end
	
	local iteration = 0
	local dadview = require("dadview")
	
	dadview.state.memory_monitor_timer = vim.loop.new_timer()
	dadview.state.memory_monitor_timer:start(interval * 1000, interval * 1000, vim.schedule_wrap(function()
		iteration = iteration + 1
		local snap = M.take_snapshot("auto_" .. iteration)
		
		-- Check for NEW buffers created
		local new_buffers = {}
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(bufnr) and not last_buffer_list[bufnr] then
				local name = vim.api.nvim_buf_get_name(bufnr)
				local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
				table.insert(new_buffers, {
					bufnr = bufnr,
					name = vim.fn.fnamemodify(name, ":t"),
					type = buftype,
				})
				last_buffer_list[bufnr] = true
			end
		end
		
		-- Compare with baseline
		if #M.snapshots >= 2 then
			local baseline = M.snapshots[1]
			local rss_delta = (snap.rss_kb - baseline.rss_kb) / 1024
			local buf_delta = snap.total_buffers - baseline.total_buffers
			local result_lines_delta = snap.result_buffer_lines - baseline.result_buffer_lines
			
			local status = "✓"
			if rss_delta > 100 then
				status = "⚠️ LEAK"
			elseif rss_delta > 50 then
				status = "⚠️"
			end
			
			print(string.format("[%d] %s RSS: %+.1f MB | Bufs: %+d | Result lines: %+d", 
				iteration, status, rss_delta, buf_delta, result_lines_delta))
			
			-- Show NEW buffers created this iteration
			if #new_buffers > 0 then
				print("  📝 NEW BUFFERS:")
				for _, buf in ipairs(new_buffers) do
					print(string.format("     #%d: %s (type: %s)", buf.bufnr, buf.name, buf.type))
				end
			end
			
			-- Detailed warning for significant leaks
			if rss_delta > 100 then
				if result_lines_delta > 10000 then
					print("  → Likely cause: Result buffer undo history accumulating!")
					print("  → Fix: Run :DadViewClearUndoHistory after big queries")
				elseif buf_delta > 3 then
					print("  → Likely cause: Too many buffers created")
					print("  → Fix: Close unused buffers with :bd")
				elseif snap.temp_sql_files > 5 then
					print(string.format("  → Likely cause: %d temp SQL files leaked", snap.temp_sql_files))
				end
			end
		end
	end))
end

-- Check undo history size
function M.check_undo_history()
	local dadview = require("dadview")
	
	if not dadview.state.result_bufnr or not vim.api.nvim_buf_is_valid(dadview.state.result_bufnr) then
		print("No result buffer found")
		return
	end
	
	local bufnr = dadview.state.result_bufnr
	local undo_info = vim.fn.undotree(bufnr)
	
	print("=== Result Buffer Undo History ===")
	print("")
	print(string.format("Buffer: %d", bufnr))
	print(string.format("Current lines: %d", vim.api.nvim_buf_line_count(bufnr)))
	
	if undo_info and undo_info.entries then
		local undo_count = #undo_info.entries
		print(string.format("Undo states: %d", undo_count))
		
		if undo_count > 10 then
			print(string.format("⚠️  %d undo states! Each may hold a full copy of query results!", undo_count))
			print("This is likely your memory leak!")
			print("")
			print("Fix with: :DadViewClearUndoHistory")
		elseif undo_count > 5 then
			print("⚠️  Moderate undo history. May contribute to memory usage.")
		else
			print("✓ Undo history looks reasonable")
		end
	else
		print("Could not read undo information")
	end
end

-- Check for duplicate connections
function M.check_duplicate_connections()
	print("=== Connection Check ===")
	print("")
	
	-- Count how many times :DadView Local has been called
	local query_buffers = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].dadview_query_buffer then
			local name = vim.api.nvim_buf_get_name(bufnr)
			local basename = vim.fn.fnamemodify(name, ":t")
			table.insert(query_buffers, basename)
		end
	end
	
	print(string.format("Query buffers: %d", #query_buffers))
	
	if #query_buffers > 3 then
		print("⚠️  You have multiple query buffers!")
		print("This happens when you run :DadView Local repeatedly.")
		print("")
		print("Query buffers:")
		for _, name in ipairs(query_buffers) do
			print("  - " .. name)
		end
		print("")
		print("Fix: Close unused buffers with :bd or :DadViewNukeAllBuffers")
	elseif #query_buffers > 1 then
		print("✓ Multiple query buffers (this is OK if you're working on multiple queries)")
	else
		print("✓ Only one query buffer (good!)")
	end
end

-- Show ALL buffers with details
function M.show_all_buffers()
	print("=== ALL BUFFERS ===")
	print("")
	
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			local basename = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
			local loaded = vim.api.nvim_buf_is_loaded(bufnr)
			local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
			local lines = loaded and vim.api.nvim_buf_line_count(bufnr) or 0
			
			local flags = {}
			if vim.b[bufnr].dadview_query_buffer then table.insert(flags, "QUERY") end
			if vim.b[bufnr].dadview_result_buffer then table.insert(flags, "RESULT") end
			if not loaded then table.insert(flags, "UNLOADED") end
			
			local flag_str = #flags > 0 and (" [" .. table.concat(flags, ",") .. "]") or ""
			
			print(string.format("  #%d: %s (%d lines, type=%s)%s", 
				bufnr, basename, lines, buftype, flag_str))
		end
	end
end

-- Comprehensive native leak diagnostics
function M.diagnose_native_leak()
	print("=== Native Code Leak Diagnostics ===")
	print("")
	
	local pid = vim.fn.getpid()
	print(string.format("Neovim PID: %d", pid))
	print("")
	
	-- 1. Check file descriptors
	print("1. Checking File Descriptors...")
	local fd_handle = io.popen(string.format("lsof -p %d 2>/dev/null | wc -l", pid))
	if fd_handle then
		local fd_count = fd_handle:read("*a")
		fd_handle:close()
		local count = tonumber(fd_count) or 0
		print(string.format("   Open file descriptors: %d", count))
		if count > 500 then
			print("   ⚠️  HIGH! Normal is < 100. Possible file descriptor leak!")
			print("   Run: lsof -p " .. pid .. " | less")
		elseif count > 200 then
			print("   ⚠️  Elevated. Monitor this.")
		else
			print("   ✓ Normal")
		end
		print("")
	end
	
	-- 2. Check for child processes
	print("2. Checking Child Processes...")
	local child_handle = io.popen(string.format("ps -o pid,command --ppid %d 2>/dev/null || pgrep -P %d 2>/dev/null", pid, pid))
	if child_handle then
		local children = child_handle:read("*a")
		child_handle:close()
		if children and children ~= "" then
			print("   ⚠️  Child processes found:")
			print(children)
		else
			print("   ✓ No child processes (good)")
		end
		print("")
	end
	
	-- 3. Check database connections
	print("3. Checking Database Processes...")
	local db_handle = io.popen("ps aux | grep -E '(psql|postgres)' | grep -v grep 2>/dev/null")
	if db_handle then
		local db_procs = db_handle:read("*a")
		db_handle:close()
		if db_procs and db_procs ~= "" then
			print("   Database processes found:")
			for line in db_procs:gmatch("[^\r\n]+") do
				print("   " .. line)
			end
		else
			print("   ✓ No orphaned database processes")
		end
		print("")
	end
	
	-- 4. Check active libuv handles
	print("4. Checking libuv Handles...")
	local dadview = require("dadview")
	local db = require("dadview.db")
	
	local handle_count = 0
	if dadview.state.memory_monitor_timer then
		print("   ⚠️  MEMORY MONITOR TIMER IS ACTIVE!")
		print("   This is likely causing file descriptor leaks via io.popen()")
		print("   Run: :lua require('dadview').state.memory_monitor_timer:close()")
		handle_count = handle_count + 1
	end
	
	local active_query_count = 0
	for query_id, _ in pairs(db.active_queries) do
		active_query_count = active_query_count + 1
	end
	
	if active_query_count > 0 then
		print(string.format("   ⚠️  %d active queries running", active_query_count))
		print("   These hold open file descriptors and subprocess handles")
		handle_count = handle_count + active_query_count
	end
	
	if handle_count == 0 then
		print("   ✓ No DadView timers or active queries")
	end
	print("")
	
	-- 5. Memory comparison
	print("5. Memory Statistics...")
	collectgarbage("collect")
	collectgarbage("collect")
	local lua_mem = collectgarbage("count")
	
	local rss_handle = io.popen(string.format("ps -o rss= -p %d 2>/dev/null", pid))
	local rss_kb = 0
	if rss_handle then
		local rss = rss_handle:read("*a")
		rss_handle:close()
		rss_kb = tonumber(rss) or 0
	end
	
	print(string.format("   Lua Memory: %.1f MB", lua_mem / 1024))
	print(string.format("   Process RSS: %.1f MB", rss_kb / 1024))
	print(string.format("   Native Memory: %.1f MB", (rss_kb / 1024) - (lua_mem / 1024)))
	print("")
	
	local ratio = (rss_kb / 1024) / (lua_mem / 1024)
	if ratio > 100 then
		print(string.format("   ⚠️  SEVERE: Native memory is %dx larger than Lua memory!", math.floor(ratio)))
		print("   This indicates a native code leak (not Lua tables/strings)")
	elseif ratio > 20 then
		print(string.format("   ⚠️  WARNING: Native memory is %dx larger than Lua memory", math.floor(ratio)))
	else
		print("   ✓ Memory ratio looks normal")
	end
	print("")
	
	-- 6. Actionable recommendations
	print("=== Recommendations ===")
	print("")
	print("To investigate further:")
	print("  1. File descriptors:  lsof -p " .. pid)
	print("  2. Heap analysis:     heap " .. pid .. " | less")
	print("  3. Leak detection:    leaks " .. pid)
	print("  4. Watch in realtime: watch -n 1 'ps -o rss -p " .. pid .. "'")
	print("")
	print("To stop potential leaks:")
	print("  :lua require('dadview.debug_memory').stop_all_monitoring()")
	print("  :lua require('dadview.db').cancel_all_queries()")
	print("")
end

-- Emergency cleanup: stop everything
function M.stop_all_monitoring()
	local dadview = require("dadview")
	local stopped = {}
	
	if dadview.state.memory_monitor_timer then
		pcall(function()
			dadview.state.memory_monitor_timer:stop()
			dadview.state.memory_monitor_timer:close()
		end)
		dadview.state.memory_monitor_timer = nil
		table.insert(stopped, "Memory monitor timer")
	end
	
	-- Force garbage collection
	collectgarbage("collect")
	collectgarbage("collect")
	
	if #stopped > 0 then
		print("Stopped: " .. table.concat(stopped, ", "))
	else
		print("No active monitoring found")
	end
	
	print("Forced garbage collection")
end

return M

