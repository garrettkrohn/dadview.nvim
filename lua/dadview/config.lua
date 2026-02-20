local M = {}

---@class DadViewConfig
---@field width number -- Width of the sidebar (default: 40)
---@field position "left"|"right" -- Position of the sidebar (default: "left")
---@field auto_open_query_buffer boolean -- Auto-open query buffer on connection (default: true)
---@field auto_execute_on_save boolean -- Auto-execute query when saving buffer (default: true)
---@field global_keymaps boolean|table -- Enable global keymaps or provide custom ones (default: true)
---@field sidebar_keymaps boolean|table -- Enable sidebar keymaps or provide custom ones (default: true)
---@field sidebar_keymaps_prefix string -- Prefix for sidebar keymaps (default: "")
---@field query_keymaps boolean|table -- Enable query buffer keymaps or provide custom ones (default: true)
---@field query_keymaps_prefix string -- Prefix for query buffer keymaps (default: "<leader>")
---@field result_keymaps boolean|table -- Enable result buffer keymaps or provide custom ones (default: true)
---@field result_keymaps_prefix string -- Prefix for result buffer keymaps (default: "")

---@type DadViewConfig
M.config = {
	width = 40,
	position = "left",
	auto_open_query_buffer = true,
	auto_execute_on_save = true,
	global_keymaps = true,
	sidebar_keymaps = true,
	sidebar_keymaps_prefix = "",
	query_keymaps = true,
	query_keymaps_prefix = "<leader>",
	result_keymaps = true,
	result_keymaps_prefix = "",
}

return M
