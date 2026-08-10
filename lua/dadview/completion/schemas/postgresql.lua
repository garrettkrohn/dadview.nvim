local M = {}

-- Get tables query
function M.get_tables_query()
  return [[
SELECT
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
]]
end

-- Get columns query for a specific table
function M.get_columns_query(schema, table)
  if schema then
    return string.format([[
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = '%s' AND table_name = '%s'
ORDER BY ordinal_position;
]], schema, table)
  else
    -- If no schema specified, try to find in any schema (prefer public)
    return string.format([[
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = '%s'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY ordinal_position;
]], table)
  end
end

-- Get schemas query
function M.get_schemas_query()
  return [[
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
ORDER BY schema_name;
]]
end

-- Parse tables from query result
function M.parse_tables(output)
  if not output or #output == 0 then
    return {}
  end

  local tables = {}
  local lines = vim.split(output, '\n', { plain = true })

  -- Skip header and separator lines
  local data_start = 1
  for i, line in ipairs(lines) do
    if line:match('^%-') then
      data_start = i + 1
      break
    end
  end

  for i = data_start, #lines do
    local line = lines[i]
    if line and #line > 0 and not line:match('^%s*$') and not line:match('^%(') then
      -- Parse "schema | table" format
      local schema, name = line:match('^%s*([^|]+)%s*|%s*([^|]+)%s*$')
      if schema and name then
        schema = schema:match('^%s*(.-)%s*$')  -- trim
        name = name:match('^%s*(.-)%s*$')      -- trim
        if schema and name and #schema > 0 and #name > 0 then
          table.insert(tables, { schema = schema, name = name })
        end
      end
    end
  end

  return tables
end

-- Parse columns from query result
function M.parse_columns(output)
  if not output or #output == 0 then
    return {}
  end

  local columns = {}
  local lines = vim.split(output, '\n', { plain = true })

  -- Skip header and separator lines
  local data_start = 1
  for i, line in ipairs(lines) do
    if line:match('^%-') then
      data_start = i + 1
      break
    end
  end

  for i = data_start, #lines do
    local line = lines[i]
    if line and #line > 0 and not line:match('^%s*$') and not line:match('^%(') then
      -- Parse "column_name | data_type | is_nullable" format
      local parts = {}
      for part in line:gmatch('[^|]+') do
        table.insert(parts, part:match('^%s*(.-)%s*$'))  -- trim
      end

      if #parts >= 2 then
        table.insert(columns, {
          name = parts[1],
          type = parts[2],
          nullable = parts[3] == 'YES',
        })
      end
    end
  end

  return columns
end

-- Parse schemas from query result
function M.parse_schemas(output)
  if not output or #output == 0 then
    return {}
  end

  local schemas = {}
  local lines = vim.split(output, '\n', { plain = true })

  -- Skip header and separator lines
  local data_start = 1
  for i, line in ipairs(lines) do
    if line:match('^%-') then
      data_start = i + 1
      break
    end
  end

  for i = data_start, #lines do
    local line = lines[i]
    if line and #line > 0 and not line:match('^%s*$') and not line:match('^%(') then
      local schema = line:match('^%s*(.-)%s*$')  -- trim
      if schema and #schema > 0 then
        table.insert(schemas, schema)
      end
    end
  end

  return schemas
end

return M
