local M = {}

M.state = {
	is_open = false,
	bufnr = nil,
	winnr = nil,
	current_connection = nil,
	connections = {},
	query_results = {}, -- Store query results by buffer -- not used
	active_queries = {}, -- Track running queries by buffer
	result_bufnr = nil, -- Single shared result buffer
	result_winnr = nil, -- Window showing the result buffer
}

return M
