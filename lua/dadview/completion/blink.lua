local M = {}

-- Get current database URL from buffer or global state
local function get_db_url(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Try buffer-local db first
  local buf_db = vim.b[bufnr].db
  if buf_db then
    return buf_db
  end

  -- Try global db
  local global_db = vim.g.db
  if global_db then
    return global_db
  end

  -- Try dadview state
  local state = require('dadview.state')
  if state.state.current_connection and state.state.current_connection.url then
    return state.state.current_connection.url
  end

  return nil
end

-- Get configuration
local function get_config()
  local config = require('dadview.config').config.completion or {}
  return {
    enabled = config.enabled ~= false,
    keywords_case = config.keywords_case or 'upper',
    trigger_characters = config.trigger_characters or { '"', "'", '`', '[', ']', '.', ' ' },
  }
end

-- Blink.cmp source implementation
M.name = 'dadview'

function M.new()
  return setmetatable({}, { __index = M })
end

-- Check if source is enabled for the current buffer
function M:enabled()
  local config = get_config()
  if not config.enabled then
    print("DadView completion: config disabled")
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Only enable for dadview query buffers
  if not vim.b[bufnr].dadview_query_buffer then
    print("DadView completion: not a query buffer")
    return false
  end

  -- Check if we have a database connection
  local db_url = get_db_url(bufnr)
  if not db_url then
    print("DadView completion: no db_url")
    return false
  end

  print("DadView completion: ENABLED")
  return true
end

-- Get trigger characters
function M:get_trigger_characters()
  local config = get_config()
  return config.trigger_characters
end

-- Resolve completion items
function M:resolve(item, callback)
  -- No additional resolution needed
  callback(item)
end

-- Execute completion
function M:complete(context, callback)
  local bufnr = context.bufnr
  local db_url = get_db_url(bufnr)

  print("DadView completion called")
  print("  DB URL: " .. tostring(db_url))

  if not db_url then
    print("  No DB URL - returning empty")
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    return
  end

  -- Get completion context
  local row = context.cursor[1]
  local col = context.cursor[2]
  local ctx_module = require('dadview.completion.context')
  local ctx_type, ctx_info = ctx_module.get_context(bufnr, row, col)

  print("  Context type: " .. tostring(ctx_type))
  print("  Context info: " .. vim.inspect(ctx_info))

  local items = {}

  -- Handle different completion contexts
  if ctx_type == 'column' then
    -- Complete columns for a specific table
    local completion = require('dadview.completion')
    local table_name = ctx_info.table
    local schema = ctx_info.schema

    -- Try to get cached columns first
    local columns = completion.get_cached_columns(db_url, schema, table_name)
    if columns then
      for _, col_info in ipairs(columns) do
        table.insert(items, {
          label = col_info.name,
          kind = 5, -- Field
          detail = col_info.type,
          documentation = string.format('%s (%s)', col_info.type, col_info.nullable and 'NULL' or 'NOT NULL'),
        })
      end
    end

    -- Fetch fresh columns asynchronously (will be available for next completion)
    completion.get_columns(db_url, schema, table_name, function() end)

  elseif ctx_type == 'table' then
    -- Complete table names
    local completion = require('dadview.completion')

    print("  Fetching tables for: " .. db_url)

    -- Try to get cached tables first
    local tables = completion.get_cached_tables(db_url)
    print("  Cached tables: " .. vim.inspect(tables))

    if tables then
      for _, tbl in ipairs(tables) do
        local label = tbl.schema and (tbl.schema .. '.' .. tbl.name) or tbl.name
        table.insert(items, {
          label = label,
          kind = 7, -- Class
          detail = 'table',
          documentation = string.format('Table: %s', label),
        })
      end
      print("  Added " .. #items .. " table items")
    end

    -- Fetch fresh tables asynchronously
    completion.get_tables(db_url, function(result, err)
      if err then
        print("  Error fetching tables: " .. tostring(err))
      else
        print("  Fetched " .. (result and #result or 0) .. " tables")
      end
    end)

  elseif ctx_type == 'schema' then
    -- Complete schema names
    local completion = require('dadview.completion')

    -- Try to get cached schemas first
    local schemas = completion.get_cached_schemas(db_url)
    if schemas then
      for _, schema in ipairs(schemas) do
        table.insert(items, {
          label = schema,
          kind = 9, -- Module
          detail = 'schema',
          documentation = string.format('Schema: %s', schema),
        })
      end
    end

    -- Fetch fresh schemas asynchronously
    completion.get_schemas(db_url, function() end)

  else
    -- Default to keyword completion
    local keywords = require('dadview.completion.keywords')
    local config = get_config()
    local kw_list = keywords.get_keywords(config.keywords_case)

    for _, kw in ipairs(kw_list) do
      table.insert(items, {
        label = kw,
        kind = 14, -- Keyword
        detail = 'SQL keyword',
      })
    end
  end

  print("  Returning " .. #items .. " completion items")

  callback({
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items,
  })
end

return M
