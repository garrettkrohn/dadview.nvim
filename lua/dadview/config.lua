local M = {}

---@class CompletionConfig
---@field enabled boolean -- Enable SQL completion (default: true)
---@field cache_ttl number -- Cache time-to-live in seconds (default: 300)
---@field keywords_case "upper"|"lower"|"mixed" -- Keyword case style (default: "upper")
---@field trigger_characters table -- Characters that trigger completion (default: { '"', "'", '`', '[', ']', '.', ' ' })

---@class DadViewConfig
---@field width number -- Width of the sidebar (default: 40)
---@field position "left"|"right" -- Position of the sidebar (default: "left")
---@field result_split "horizontal"|"vertical" -- Split direction for result buffer (default: "horizontal")
---@field auto_open_query_buffer boolean -- Auto-open query buffer on connection (default: true)
---@field reuse_query_buffer boolean -- Reuse most recent query file instead of creating new ones (default: false)
---@field auto_execute_on_save boolean -- Auto-execute query when saving buffer (default: true)
---@field global_keymaps boolean|table -- Enable global keymaps or provide custom ones (default: true)
---@field sidebar_keymaps boolean|table -- Enable sidebar keymaps or provide custom ones (default: true)
---@field sidebar_keymaps_prefix string -- Prefix for sidebar keymaps (default: "")
---@field query_keymaps boolean|table -- Enable query buffer keymaps or provide custom ones (default: true)
---@field query_keymaps_prefix string -- Prefix for query buffer keymaps (default: "<leader>")
---@field result_keymaps boolean|table -- Enable result buffer keymaps or provide custom ones (default: true)
---@field result_keymaps_prefix string -- Prefix for result buffer keymaps (default: "")
---@field completion CompletionConfig|nil -- SQL completion configuration

---@type DadViewConfig
M.config = {
	width = 40,
	position = "left",
	result_split = "horizontal",
	auto_open_query_buffer = true,
	reuse_query_buffer = false,
	auto_execute_on_save = false,
	global_keymaps = true,
	sidebar_keymaps = true,
	sidebar_keymaps_prefix = "",
	query_keymaps = true,
	query_keymaps_prefix = "<leader>",
	result_keymaps = true,
	result_keymaps_prefix = "",
	completion = {
		enabled = true,
		cache_ttl = 300,
		keywords_case = "upper",
		trigger_characters = { '"', "'", "`", "[", "]", ".", " " },
	},
}

return M
