local M = {}

-- Extract the text before the cursor for context analysis
local function get_line_before_cursor(line, col)
  return line:sub(1, col)
end

-- Check if we're in a column context (after table. or schema.table.)
function M.is_column_context(line_before_cursor)
  -- Match patterns like:
  -- - "table."
  -- - "schema.table."
  -- - "t." (alias)
  -- The pattern should end with a dot
  local pattern = '%w+%.$'
  local double_pattern = '%w+%.%w+%.$'

  if line_before_cursor:match(double_pattern) then
    -- schema.table. format
    local schema, table = line_before_cursor:match('(%w+)%.(%w+)%.$')
    return true, { schema = schema, table = table }
  elseif line_before_cursor:match(pattern) then
    -- table. format
    local table = line_before_cursor:match('(%w+)%.$')
    return true, { table = table }
  end

  return false, nil
end

-- Check if we're in a schema context (after database.)
function M.is_schema_context(line_before_cursor)
  -- This is less common but we can detect schema completion after certain keywords
  -- For now, we'll keep it simple
  return false, nil
end

-- Check if we're in a table context (after FROM, JOIN, UPDATE, INTO, etc.)
function M.is_table_context(line_before_cursor)
  -- Keywords that typically precede table names
  local table_keywords = {
    'FROM',
    'JOIN',
    'INNER JOIN',
    'LEFT JOIN',
    'RIGHT JOIN',
    'FULL JOIN',
    'CROSS JOIN',
    'INTO',
    'UPDATE',
    'TABLE',
    'TRUNCATE',
  }

  -- Normalize the line (uppercase for comparison)
  local normalized = line_before_cursor:upper()

  for _, keyword in ipairs(table_keywords) do
    -- Check if keyword appears followed by whitespace (but not completed with table name yet)
    if normalized:match(keyword .. '%s+$') or
       normalized:match(keyword .. '%s+%w+$') then
      return true
    end
  end

  return false
end

-- Determine the completion context for the current cursor position
function M.get_context(bufnr, row, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if row > #lines then
    return 'none'
  end

  local line = lines[row]
  local line_before_cursor = get_line_before_cursor(line, col)

  -- Check for column context first (most specific)
  local is_column, column_info = M.is_column_context(line_before_cursor)
  if is_column then
    return 'column', column_info
  end

  -- Check for schema context
  local is_schema, schema_info = M.is_schema_context(line_before_cursor)
  if is_schema then
    return 'schema', schema_info
  end

  -- Check for table context
  if M.is_table_context(line_before_cursor) then
    return 'table', nil
  end

  -- Default to keyword context
  return 'keyword', nil
end

return M
