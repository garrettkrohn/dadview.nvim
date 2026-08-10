local M = {}

-- Cache structure: cache[db_url] = { tables, columns, schemas, metadata }
local cache = {}

-- Get configuration (with defaults)
local function get_config()
  local config = require('dadview.config').config.completion or {}
  return {
    cache_ttl = config.cache_ttl or 300, -- 5 minutes default
  }
end

-- Check if cache is expired
local function is_cache_expired(metadata)
  if not metadata or not metadata.fetched_at then
    return true
  end
  local config = get_config()
  local age = os.time() - metadata.fetched_at
  return age > config.cache_ttl
end

-- Get or initialize cache entry for a database
local function get_cache_entry(db_url)
  if not cache[db_url] then
    cache[db_url] = {
      tables = nil,
      columns = {},
      schemas = nil,
      metadata = {
        fetched_at = nil,
      },
    }
  end
  return cache[db_url]
end

-- Get tables from cache or fetch from database
function M.get_tables(db_url, callback)
  local entry = get_cache_entry(db_url)

  -- Return cached tables if available and not expired
  if entry.tables and not is_cache_expired(entry.metadata) then
    callback(entry.tables, nil)
    return
  end

  -- Fetch tables from database
  local adapters = require('dadview.adapters')
  local adapter, err = adapters.get_adapter(db_url)
  if not adapter then
    callback(nil, err)
    return
  end

  if not adapter.get_tables then
    callback(nil, 'Adapter does not support table listing')
    return
  end

  local parsed, parse_err = adapter.parse_url(db_url)
  if not parsed then
    callback(nil, parse_err)
    return
  end

  -- Fetch asynchronously
  vim.schedule(function()
    local tables, fetch_err = adapter.get_tables(parsed)
    if tables then
      entry.tables = tables
      entry.metadata.fetched_at = os.time()
      callback(tables, nil)
    else
      callback(nil, fetch_err)
    end
  end)
end

-- Get columns from cache or fetch from database
function M.get_columns(db_url, schema, table_name, callback)
  local entry = get_cache_entry(db_url)

  -- Create cache key
  local cache_key = schema and (schema .. '.' .. table_name) or table_name

  -- Return cached columns if available and not expired
  if entry.columns[cache_key] and not is_cache_expired(entry.metadata) then
    callback(entry.columns[cache_key], nil)
    return
  end

  -- Fetch columns from database
  local adapters = require('dadview.adapters')
  local adapter, err = adapters.get_adapter(db_url)
  if not adapter then
    callback(nil, err)
    return
  end

  if not adapter.get_columns then
    callback(nil, 'Adapter does not support column listing')
    return
  end

  local parsed, parse_err = adapter.parse_url(db_url)
  if not parsed then
    callback(nil, parse_err)
    return
  end

  -- Fetch asynchronously
  vim.schedule(function()
    local columns, fetch_err = adapter.get_columns(parsed, {
      schema = schema,
      table = table_name,
    })
    if columns then
      entry.columns[cache_key] = columns
      entry.metadata.fetched_at = os.time()
      callback(columns, nil)
    else
      callback(nil, fetch_err)
    end
  end)
end

-- Get schemas from cache or fetch from database
function M.get_schemas(db_url, callback)
  local entry = get_cache_entry(db_url)

  -- Return cached schemas if available and not expired
  if entry.schemas and not is_cache_expired(entry.metadata) then
    callback(entry.schemas, nil)
    return
  end

  -- Fetch schemas from database
  local adapters = require('dadview.adapters')
  local adapter, err = adapters.get_adapter(db_url)
  if not adapter then
    callback(nil, err)
    return
  end

  if not adapter.get_schemas then
    callback(nil, 'Adapter does not support schema listing')
    return
  end

  local parsed, parse_err = adapter.parse_url(db_url)
  if not parsed then
    callback(nil, parse_err)
    return
  end

  -- Fetch asynchronously
  vim.schedule(function()
    local schemas, fetch_err = adapter.get_schemas(parsed)
    if schemas then
      entry.schemas = schemas
      entry.metadata.fetched_at = os.time()
      callback(schemas, nil)
    else
      callback(nil, fetch_err)
    end
  end)
end

-- Invalidate cache for a database connection
function M.invalidate_cache(db_url)
  if db_url then
    cache[db_url] = nil
  else
    cache = {}
  end
end

-- Get cached tables synchronously (returns nil if not cached)
function M.get_cached_tables(db_url)
  local entry = cache[db_url]
  if entry and entry.tables and not is_cache_expired(entry.metadata) then
    return entry.tables
  end
  return nil
end

-- Get cached columns synchronously (returns nil if not cached)
function M.get_cached_columns(db_url, schema, table_name)
  local entry = cache[db_url]
  if not entry then
    return nil
  end

  local cache_key = schema and (schema .. '.' .. table_name) or table_name
  if entry.columns[cache_key] and not is_cache_expired(entry.metadata) then
    return entry.columns[cache_key]
  end
  return nil
end

-- Get cached schemas synchronously (returns nil if not cached)
function M.get_cached_schemas(db_url)
  local entry = cache[db_url]
  if entry and entry.schemas and not is_cache_expired(entry.metadata) then
    return entry.schemas
  end
  return nil
end

return M
