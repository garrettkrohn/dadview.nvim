local M = {}

-- URL decode helper
local function url_decode(str)
  if not str then return nil end
  str = str:gsub('+', ' ')
  str = str:gsub('%%(%x%x)', function(h)
    return string.char(tonumber(h, 16))
  end)
  return str
end

-- Parse JDBC URL
-- Supports Oracle Thin format: jdbc:oracle:thin:@host:port/service_name
-- Also supports jdbc:oracle:thin:@host:port:sid
function M.parse_url(url)
  if not url or type(url) ~= 'string' then
    return nil, 'URL must be a string'
  end

  -- Strip scheme and validate
  local scheme, subprotocol, driver, rest = url:match('^(jdbc):([^:]+):([^:]+):(.*)$')
  if not scheme or scheme ~= 'jdbc' then
    return nil, 'URL must start with jdbc:'
  end

  local result = {
    scheme = 'jdbc',
    subprotocol = subprotocol,
    driver = driver,
    raw_url = url,
    params = {},
  }

  -- Parse Oracle thin URL format
  if subprotocol == 'oracle' and driver == 'thin' then
    -- Remove leading @ if present
    rest = rest:match('^@?(.*)$')

    -- Extract connection string and parameters
    local conn_part, query = rest:match('^(.-)%?(.*)$')
    if query then
      rest = conn_part
      -- Parse query parameters
      for key, value in query:gmatch('([^&=]+)=([^&=]+)') do
        result.params[url_decode(key)] = url_decode(value)
      end
    end

    -- Check for user/password in params or extract from connection string
    if result.params.user then
      result.user = result.params.user
      result.params.user = nil
    end
    if result.params.password then
      result.password = result.params.password
      result.params.password = nil
    end

    -- Parse host:port/service or host:port:sid format
    local host, port, service = rest:match('^([^:]+):(%d+)/(.*)$')
    if host then
      -- Service name format
      result.host = host
      result.port = tonumber(port)
      result.service_name = service
    else
      -- Try SID format
      host, port, service = rest:match('^([^:]+):(%d+):(.*)$')
      if host then
        result.host = host
        result.port = tonumber(port)
        result.sid = service
      else
        return nil, 'Invalid Oracle JDBC URL format. Expected: jdbc:oracle:thin:@host:port/service or jdbc:oracle:thin:@host:port:sid'
      end
    end
  else
    return nil, string.format('Unsupported JDBC driver: %s:%s', subprotocol, driver)
  end

  -- Set defaults
  result.port = result.port or 1521

  return result
end

-- Build SQLcl or SQLPlus command
function M.build_command(parsed, opts)
  opts = opts or {}

  -- Prefer sqlcl (Oracle SQL Developer Command Line) for better JDBC support
  -- Falls back to sqlplus if sqlcl is not available
  local has_sqlcl = vim.fn.executable('sql') == 1
  local has_sqlplus = vim.fn.executable('sqlplus') == 1

  if not has_sqlcl and not has_sqlplus then
    return nil, 'Neither sql (SQLcl) nor sqlplus found. Please install Oracle SQL Developer Command Line (SQLcl) or SQL*Plus'
  end

  local cmd = {}
  local env = {}

  if has_sqlcl then
    -- Use SQLcl (modern, better support)
    table.insert(cmd, 'sql')
    table.insert(cmd, '-S')  -- Silent mode (suppress banner)
    table.insert(cmd, '-L')  -- Log on once (fail fast on connection error)

    -- Build connection string
    local conn_str
    if parsed.user and parsed.password then
      if parsed.service_name then
        conn_str = string.format('%s/%s@%s:%d/%s',
          parsed.user, parsed.password, parsed.host, parsed.port, parsed.service_name)
      else
        conn_str = string.format('%s/%s@%s:%d:%s',
          parsed.user, parsed.password, parsed.host, parsed.port, parsed.sid)
      end
    else
      return nil, 'JDBC URL must include user credentials'
    end

    table.insert(cmd, conn_str)

  else
    -- Use SQL*Plus (legacy but widely available)
    table.insert(cmd, 'sqlplus')
    table.insert(cmd, '-S')  -- Silent mode
    table.insert(cmd, '-L')  -- Log on once

    -- Build connection string
    local conn_str
    if parsed.user and parsed.password then
      if parsed.service_name then
        conn_str = string.format('%s/%s@//%s:%d/%s',
          parsed.user, parsed.password, parsed.host, parsed.port, parsed.service_name)
      else
        conn_str = string.format('%s/%s@%s:%d:%s',
          parsed.user, parsed.password, parsed.host, parsed.port, parsed.sid)
      end
    else
      return nil, 'JDBC URL must include user credentials'
    end

    table.insert(cmd, conn_str)
  end

  -- Add file or query execution
  if opts.test then
    -- For connection testing
    table.insert(cmd, '/nolog')  -- Don't log in yet
  elseif opts.query then
    -- Note: passing query directly is complex with sqlplus/sqlcl
    -- It's better to use file mode
    return nil, 'Direct query mode not supported, use file mode instead'
  elseif opts.file then
    -- Create a wrapper script with formatting commands
    local wrapper_file = vim.fn.tempname() .. '.sql'
    local file = io.open(wrapper_file, 'w')
    if not file then
      return nil, 'Failed to create wrapper script'
    end

    -- Write formatting commands for cleaner output
    file:write('SET PAGESIZE 50000\n')        -- Large page size (avoid pagination)
    file:write('SET LINESIZE 32767\n')        -- Maximum line size
    file:write('SET WRAP OFF\n')              -- Don't wrap long lines
    file:write('SET TRIMOUT ON\n')            -- Trim trailing spaces
    file:write('SET TRIMSPOOL ON\n')          -- Trim trailing spaces in spooled output
    file:write('SET FEEDBACK OFF\n')          -- Disable "X rows selected" message
    file:write('SET HEADING ON\n')            -- Keep column headers
    file:write('SET ECHO OFF\n')              -- Don't echo commands
    file:write('SET VERIFY OFF\n')            -- Don't show before/after substitution
    file:write('SET TERMOUT ON\n')            -- Show output on terminal
    file:write('SET MARKUP HTML OFF\n')       -- Disable HTML/ANSI formatting
    file:write('SET SQLFORMAT ANSICONSOLE\n') -- Plain console output
    file:write('\n')

    -- Execute the actual query file
    file:write('@' .. opts.file .. '\n')
    file:write('EXIT;\n')
    file:close()

    table.insert(cmd, '@' .. wrapper_file)
  end

  return cmd, env
end

-- Parse column positions from SQLcl output
local function parse_columns(header_line, separator_line)
  local columns = {}
  local pos = 1

  -- Find each column based on separator underscores
  for col_sep in separator_line:gmatch('[_]+') do
    local start_pos = separator_line:find(col_sep, pos, true)
    local end_pos = start_pos + #col_sep - 1

    -- Extract column name from header
    local col_name = header_line:sub(start_pos, end_pos):match('^%s*(.-)%s*$')

    table.insert(columns, {
      name = col_name,
      start_pos = start_pos,
      end_pos = end_pos,
      width = #col_sep,
    })

    pos = end_pos + 1
  end

  return columns
end

-- Extract cell value from line based on column position
local function extract_cell(line, column)
  if #line < column.start_pos then
    return ''
  end
  local end_pos = math.min(column.end_pos, #line)
  local value = line:sub(column.start_pos, end_pos)
  return value:match('^%s*(.-)%s*$') or ''  -- Trim whitespace
end

-- Strip ANSI escape codes from string
local function strip_ansi(str)
  -- Remove ANSI escape sequences (color codes, bold, etc.)
  -- Pattern: ESC [ ... m  where ESC is \027 or \x1b
  return str:gsub('\027%[[%d;]*m', '')
end

-- Format query results
function M.format_results(output, opts)
  opts = opts or {}

  if not output or #output == 0 then
    return '-- No results'
  end

  -- Strip ANSI codes first
  output = strip_ansi(output)

  -- Clean up SQL*Plus/SQLcl output
  local lines = vim.split(output, '\n', { plain = true })
  local clean_lines = {}

  for _, line in ipairs(lines) do
    -- Skip common SQL*Plus/SQLcl noise
    if not line:match('^Connected to:') and
       not line:match('^Oracle Database') and
       not line:match('^Copyright') and
       not line:match('^Disconnected from') and
       not line:match('^SQL>') and
       not line:match('^%s*SQL>') and
       not line:match('^%s*$') then
      table.insert(clean_lines, line)
    end
  end

  if #clean_lines == 0 then
    return '-- No results'
  end

  -- Look for header and separator pattern
  local header_line = nil
  local separator_line = nil
  local data_start_idx = nil

  for i, line in ipairs(clean_lines) do
    if line:match('^_+') then
      separator_line = line
      if i > 1 then
        header_line = clean_lines[i - 1]
        data_start_idx = i + 1
      end
      break
    end
  end

  -- If we found a proper table structure, format it nicely
  if header_line and separator_line and data_start_idx then
    local columns = parse_columns(header_line, separator_line)

    if #columns > 0 then
      local formatted = {}

      -- Format header
      local header_parts = {}
      for _, col in ipairs(columns) do
        table.insert(header_parts, string.format(' %-' .. col.width .. 's', col.name))
      end
      table.insert(formatted, '|' .. table.concat(header_parts, ' |') .. ' |')

      -- Add separator line
      local sep_parts = {}
      for _, col in ipairs(columns) do
        table.insert(sep_parts, string.rep('-', col.width + 2))
      end
      table.insert(formatted, '|' .. table.concat(sep_parts, '|') .. '|')

      -- Format data rows
      for i = data_start_idx, #clean_lines do
        local line = clean_lines[i]
        if #line > 0 then
          local row_parts = {}
          for _, col in ipairs(columns) do
            local value = extract_cell(line, col)
            table.insert(row_parts, string.format(' %-' .. col.width .. 's', value))
          end
          table.insert(formatted, '|' .. table.concat(row_parts, ' |') .. ' |')
        end
      end

      return table.concat(formatted, '\n')
    end
  end

  -- Fallback: return cleaned output without formatting
  return table.concat(clean_lines, '\n')
end

-- Test connection
function M.test_connection(parsed)
  local cmd, env = M.build_command(parsed, {})
  if not cmd then
    return false, env or 'Failed to build command'
  end

  -- Create a simple test query
  local temp_file = vim.fn.tempname() .. '.sql'
  local file = io.open(temp_file, 'w')
  if not file then
    return false, 'Failed to create temp file for connection test'
  end

  file:write('SELECT 1 FROM DUAL;\n')
  file:write('EXIT;\n')
  file:close()

  -- Update command to use test file
  table.insert(cmd, '@' .. temp_file)

  local result = vim.system(cmd, {
    env = env,
    text = true,
  }):wait()

  -- Clean up temp file
  vim.fn.delete(temp_file)

  if result.code == 0 then
    return true, nil
  else
    local error_msg = result.stderr or result.stdout or 'Unknown error'
    -- Extract first meaningful error line
    for line in error_msg:gmatch('[^\n]+') do
      if line:match('ORA%-') or line:match('[Ee]rror') then
        return false, line
      end
    end
    return false, error_msg:match('([^\n]+)')
  end
end

return M
