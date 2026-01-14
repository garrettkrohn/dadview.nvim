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

-- URL encode helper
local function url_encode(str)
  if not str then return nil end
  str = str:gsub('\n', '\r\n')
  str = str:gsub('([^%w%.%-_~])', function(c)
    return string.format('%%%02X', string.byte(c))
  end)
  return str
end

-- Parse PostgreSQL URL
-- Format: postgresql://[user[:password]@][host][:port][/database][?param=value]
function M.parse_url(url)
  if not url or type(url) ~= 'string' then
    return nil, 'URL must be a string'
  end
  
  -- Strip scheme
  local scheme, rest = url:match('^([^:]+)://(.*)$')
  if not scheme or (scheme ~= 'postgresql' and scheme ~= 'postgres') then
    return nil, 'URL must start with postgresql:// or postgres://'
  end
  
  local result = {
    scheme = 'postgresql',
    raw_url = url,
  }
  
  -- Extract query parameters (everything after ?)
  local path_part, query = rest:match('^(.-)%?(.*)$')
  if query then
    rest = path_part
    result.params = {}
    for key, value in query:gmatch('([^&=]+)=([^&=]+)') do
      result.params[url_decode(key)] = url_decode(value)
    end
  else
    result.params = {}
  end
  
  -- Extract user:password@host:port/database
  local auth, location = rest:match('^(.-)@(.*)$')
  if auth then
    -- Has authentication
    local user, password = auth:match('^([^:]+):(.*)$')
    if user then
      result.user = url_decode(user)
      result.password = url_decode(password)
    else
      result.user = url_decode(auth)
    end
    rest = location
  end
  
  -- Extract host:port/database
  local host_port, database = rest:match('^([^/]*)/(.*)$')
  if host_port then
    -- Has database
    result.database = url_decode(database)
    rest = host_port
  else
    host_port = rest
  end
  
  -- Extract host:port
  if host_port and host_port ~= '' then
    local host, port = host_port:match('^([^:]+):(%d+)$')
    if host then
      result.host = url_decode(host)
      result.port = tonumber(port)
    else
      result.host = url_decode(host_port)
    end
  end
  
  -- Set defaults
  result.host = result.host or 'localhost'
  result.port = result.port or 5432
  
  return result
end

-- Build psql command
function M.build_command(parsed, opts)
  opts = opts or {}
  
  local cmd = { 'psql' }
  
  -- Build connection string
  local conn_parts = {}
  
  if parsed.host then
    table.insert(conn_parts, 'host=' .. parsed.host)
  end
  
  if parsed.port then
    table.insert(conn_parts, 'port=' .. tostring(parsed.port))
  end
  
  if parsed.user then
    table.insert(conn_parts, 'user=' .. parsed.user)
  end
  
  if parsed.database then
    table.insert(conn_parts, 'dbname=' .. parsed.database)
  end
  
  -- Add connection parameters
  for key, value in pairs(parsed.params) do
    table.insert(conn_parts, key .. '=' .. value)
  end
  
  table.insert(cmd, '--dbname=' .. table.concat(conn_parts, ' '))
  
  -- Add password via environment variable if present
  local env = {}
  if parsed.password then
    env.PGPASSWORD = parsed.password
  end
  
  -- Add common options
  if not opts.interactive then
    table.insert(cmd, '--no-psqlrc')  -- Don't load .psqlrc
    table.insert(cmd, '-X')            -- Don't read startup file
  end
  
  if opts.test then
    -- For connection testing
    table.insert(cmd, '-c')
    table.insert(cmd, 'SELECT 1;')
    table.insert(cmd, '-t')  -- Tuples only
    table.insert(cmd, '-A')  -- Unaligned output
  elseif opts.query then
    -- Execute a query from command line
    table.insert(cmd, '-c')
    table.insert(cmd, opts.query)
  elseif opts.file then
    -- Execute a file
    table.insert(cmd, '-f')
    table.insert(cmd, opts.file)
  end
  
  -- Output formatting
  if not opts.interactive and not opts.test then
    table.insert(cmd, '--pset=pager=off')  -- Disable pager
    table.insert(cmd, '-v')
    table.insert(cmd, 'ON_ERROR_STOP=1')   -- Stop on error
  end
  
  return cmd, env
end

-- Format query results
function M.format_results(output, opts)
  opts = opts or {}
  
  if not output or #output == 0 then
    return '-- No results'
  end
  
  -- Output is already formatted by psql
  -- Just clean up any trailing whitespace
  local lines = vim.split(output, '\n', { plain = true })
  
  -- Remove empty trailing lines
  while #lines > 0 and lines[#lines]:match('^%s*$') do
    table.remove(lines)
  end
  
  return table.concat(lines, '\n')
end

-- Test connection
function M.test_connection(parsed)
  local cmd, env = M.build_command(parsed, { test = true })
  
  local result = vim.system(cmd, {
    env = env,
    text = true,
  }):wait()
  
  if result.code == 0 then
    return true, nil
  else
    local error_msg = result.stderr or result.stdout or 'Unknown error'
    return false, error_msg:match('([^\n]+)') -- First line of error
  end
end

-- Get table list (bonus feature for future autocomplete)
function M.get_tables(parsed)
  local cmd, env = M.build_command(parsed, {
    query = [[\dt]],
  })
  table.insert(cmd, '-t')  -- Tuples only
  table.insert(cmd, '-A')  -- Unaligned
  
  local result = vim.system(cmd, {
    env = env,
    text = true,
  }):wait()
  
  if result.code ~= 0 then
    return nil, result.stderr
  end
  
  local tables = {}
  for line in result.stdout:gmatch('[^\n]+') do
    local schema, name = line:match('^([^|]+)|([^|]+)')
    if name then
      table.insert(tables, { schema = schema, name = name })
    end
  end
  
  return tables
end

return M

