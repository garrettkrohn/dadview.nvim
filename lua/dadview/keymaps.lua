local M = {}

M.default_global_keymaps = {
	["Toggle DadView"] = {
		"<leader>db",
		function()
			require("dadview.sidebar").toggle()
		end,
	},
}

M.default_sidebar_keymaps = {
	["Connect to database"] = {
		"<CR>",
		function()
			require("dadview.sidebar").connect_at_cursor()
		end,
		prefix = false,
	},
	["Refresh connections"] = {
		"R",
		function()
			require("dadview.sidebar").render()
		end,
		prefix = false,
	},
	["Show help"] = {
		"?",
		function()
			require("dadview.sidebar").show_help()
		end,
		prefix = false,
	},
	["Close sidebar"] = {
		"q",
		function()
			require("dadview.sidebar").close()
		end,
		prefix = false,
	},
}

M.default_query_keymaps = {
	["Execute query"] = {
		"r",
		function()
			local bufnr = vim.api.nvim_get_current_buf()
			require("dadview.executor").execute_query_buffer(bufnr)
		end,
	},
	["Execute query <CR>"] = {
		"<C-CR>",
		function()
			local bufnr = vim.api.nvim_get_current_buf()
			require("dadview.executor").execute_query_buffer(bufnr)
		end,
		prefix = false,
	},
	["Cancel query"] = {
		"<C-c>",
		function()
			local bufnr = vim.api.nvim_get_current_buf()
			require("dadview.executor").cancel_query(bufnr)
		end,
		prefix = false,
	},
	["Next column"] = {
		"<C-n>",
		function()
			vim.fn.search("|", "W")
		end,
		prefix = false,
	},
	["Previous column"] = {
		"<C-p>",
		function()
			vim.fn.search("|", "bW")
		end,
		prefix = false,
	},
	["Quit all"] = {
		"q",
		function()
			require("dadview.sidebar").quit_all()
		end,
		prefix = false,
	},
}

M.default_result_keymaps = {
	["Next column"] = {
		"<C-n>",
		function()
			vim.fn.search("|", "W")
		end,
		prefix = false,
	},
	["Previous column"] = {
		"<C-p>",
		function()
			vim.fn.search("|", "bW")
		end,
		prefix = false,
	},
	["Quit all"] = {
		"q",
		function()
			require("dadview.sidebar").quit_all()
		end,
		prefix = false,
	},
}

local function set_keymap(map, buf)
	vim.keymap.set(map.mode or "n", map[1], map[2], {
		buffer = buf,
		desc = map.desc,
		silent = true,
		nowait = true,
	})
end

M.get_sidebar_keymaps = function()
	local config = require("dadview.config")
	local config_sidebar_keymaps = config.config.sidebar_keymaps

	if config_sidebar_keymaps == false then
		return {}
	end

	local default_keymaps = vim.deepcopy(M.default_sidebar_keymaps)
	local prefix = config.config.sidebar_keymaps_prefix or ""

	vim.iter(default_keymaps):each(function(name, map)
		map[1] = map.prefix == false and map[1] or prefix .. map[1]
		default_keymaps[name] = map
	end)

	config_sidebar_keymaps = type(config_sidebar_keymaps) == "table"
			and vim.tbl_extend("force", default_keymaps, config_sidebar_keymaps)
		or default_keymaps

	return config_sidebar_keymaps
end

M.get_query_keymaps = function()
	local config = require("dadview.config")
	local config_query_keymaps = config.config.query_keymaps

	if config_query_keymaps == false then
		return {}
	end

	local default_keymaps = vim.deepcopy(M.default_query_keymaps)
	local prefix = config.config.query_keymaps_prefix or "<leader>"

	vim.iter(default_keymaps):each(function(name, map)
		map[1] = map.prefix == false and map[1] or prefix .. map[1]
		default_keymaps[name] = map
	end)

	config_query_keymaps = type(config_query_keymaps) == "table"
			and vim.tbl_extend("force", default_keymaps, config_query_keymaps)
		or default_keymaps

	return config_query_keymaps
end

M.get_global_keymaps = function()
	local config = require("dadview.config")
	local config_global_keymaps = config.config.global_keymaps

	if config_global_keymaps == false then
		return {}
	end

	local default_keymaps = vim.deepcopy(M.default_global_keymaps)

	config_global_keymaps = type(config_global_keymaps) == "table"
			and vim.tbl_extend("force", default_keymaps, config_global_keymaps)
		or default_keymaps

	return config_global_keymaps
end

M.get_result_keymaps = function()
	local config = require("dadview.config")
	local config_result_keymaps = config.config.result_keymaps

	if config_result_keymaps == false then
		return {}
	end

	local default_keymaps = vim.deepcopy(M.default_result_keymaps)
	local prefix = config.config.result_keymaps_prefix or ""

	vim.iter(default_keymaps):each(function(name, map)
		map[1] = map.prefix == false and map[1] or prefix .. map[1]
		default_keymaps[name] = map
	end)

	config_result_keymaps = type(config_result_keymaps) == "table"
			and vim.tbl_extend("force", default_keymaps, config_result_keymaps)
		or default_keymaps

	return config_result_keymaps
end

M.setup_sidebar_keymaps = function(buf)
	local keymaps = M.get_sidebar_keymaps()

	vim.iter(keymaps):each(function(name, map)
		if map then
			map.desc = map.desc or name
			set_keymap(map, buf)
		end
	end)

	return keymaps
end

M.setup_query_buffer_keymaps = function(bufnr)
	local keymaps = M.get_query_keymaps()

	vim.iter(keymaps):each(function(name, map)
		if map then
			map.desc = map.desc or name
			set_keymap(map, bufnr)
		end
	end)

	return keymaps
end

M.setup_global_keymaps = function()
	local keymaps = M.get_global_keymaps()

	vim.iter(keymaps):each(function(name, map)
		if map then
			map.desc = map.desc or name
			set_keymap(map)
		end
	end)

	return keymaps
end

M.setup_result_buffer_keymaps = function(bufnr)
	local keymaps = M.get_result_keymaps()

	vim.iter(keymaps):each(function(name, map)
		if map then
			map.desc = map.desc or name
			set_keymap(map, bufnr)
		end
	end)

	return keymaps
end

return M
