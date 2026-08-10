local M = {}

-- Get tables query
function M.get_tables_query()
  return [[
SELECT
  owner,
  table_name
FROM all_tables
WHERE owner NOT IN ('SYS', 'SYSTEM', 'CTXSYS', 'MDSYS', 'OLAPSYS', 'ORDSYS', 'OUTLN', 'WMSYS', 'XDB')
ORDER BY owner, table_name;
]]
end

-- Get columns query for a specific table
function M.get_columns_query(schema, table)
  if schema then
    return string.format([[
SELECT
  column_name,
  data_type,
  nullable
FROM all_tab_columns
WHERE owner = '%s' AND table_name = '%s'
ORDER BY column_id;
]], schema:upper(), table:upper())
  else
    -- If no schema specified, try user's schema first, then search all
    return string.format([[
SELECT
  column_name,
  data_type,
  nullable
FROM all_tab_columns
WHERE table_name = '%s'
  AND owner = USER
ORDER BY column_id;
]], table:upper())
  end
end

-- Get schemas query
function M.get_schemas_query()
  return [[
SELECT username
FROM all_users
WHERE username NOT IN ('SYS', 'SYSTEM', 'CTXSYS', 'MDSYS', 'OLAPSYS', 'ORDSYS', 'OUTLN', 'WMSYS', 'XDB')
ORDER BY username;
]]
end

-- Parse tables from query result (Oracle format with | separators)
function M.parse_tables(output)
  if not output or #output == 0 then
    return {}
  end

  local tables = {}
  local lines = vim.split(output, '\n', { plain = true })

  -- Skip header and separator lines
  local data_start = 1
  for i, line in ipairs(lines) do
    if line:match('^%-') or line:match('^_') then
      data_start = i + 1
      break
    end
  end

  for i = data_start, #lines do
    local line = lines[i]
    if line and #line > 0 and not line:match('^%s*$') then
      -- Parse "owner | table" format
      local parts = {}
      for part in line:gmatch('[^|]+') do
        local trimmed = part:match('^%s*(.-)%s*$')  -- trim
        if trimmed and #trimmed > 0 then
          table.insert(parts, trimmed)
        end
      end

      if #parts >= 2 then
        table.insert(tables, { schema = parts[1], name = parts[2] })
      end
    end
  end

  return tables
end

-- Parse columns from query result (Oracle format)
function M.parse_columns(output)
  if not output or #output == 0 then
    return {}
  end

  local columns = {}
  local lines = vim.split(output, '\n', { plain = true })

  -- Skip header and separator lines
  local data_start = 1
  for i, line in ipairs(lines) do
    if line:match('^%-') or line:match('^_') then
      data_start = i + 1
      break
    end
  end

  for i = data_start, #lines do
    local line = lines[i]
    if line and #line > 0 and not line:match('^%s*$') then
      -- Parse "column_name | data_type | nullable" format
      local parts = {}
      for part in line:gmatch('[^|]+') do
        local trimmed = part:match('^%s*(.-)%s*$')  -- trim
        if trimmed and #trimmed > 0 then
          table.insert(parts, trimmed)
        end
      end

      if #parts >= 2 then
        table.insert(columns, {
          name = parts[1],
          type = parts[2],
          nullable = parts[3] == 'Y',
        })
      end
    end
  end

  return columns
end

-- Parse schemas from query result (Oracle format)
function M.parse_schemas(output)
  if not output or #output == 0 then
    return {}
  end

  local schemas = {}
  local lines = vim.split(output, '\n', { plain = true })

  -- Skip header and separator lines
  local data_start = 1
  for i, line in ipairs(lines) do
    if line:match('^%-') or line:match('^_') then
      data_start = i + 1
      break
    end
  end

  for i = data_start, #lines do
    local line = lines[i]
    if line and #line > 0 and not line:match('^%s*$') then
      local schema = line:match('^%s*(.-)%s*$')  -- trim
      if schema and #schema > 0 then
        table.insert(schemas, schema)
      end
    end
  end

  return schemas
end

return M
