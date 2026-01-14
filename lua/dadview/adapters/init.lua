local M = {}

-- Registry of available adapters
M.adapters = {}

-- Register a new adapter
function M.register(scheme, adapter)
  if not adapter.parse_url then
    error('Adapter must implement parse_url()')
  end
  if not adapter.build_command then
    error('Adapter must implement build_command()')
  end
  if not adapter.format_results then
    error('Adapter must implement format_results()')
  end
  
  M.adapters[scheme] = adapter
end

-- Get adapter for a URL
function M.get_adapter(url)
  if type(url) ~= 'string' then
    return nil, 'URL must be a string'
  end
  
  local scheme = url:match('^([^:]+):')
  if not scheme then
    return nil, 'Invalid URL: missing scheme'
  end
  
  scheme = scheme:lower()
  local adapter = M.adapters[scheme]
  
  if not adapter then
    return nil, string.format('No adapter found for scheme: %s', scheme)
  end
  
  return adapter, nil
end

-- Parse a database URL
function M.parse_url(url)
  local adapter, err = M.get_adapter(url)
  if not adapter then
    return nil, err
  end
  
  return adapter.parse_url(url)
end

-- Build command for executing a query
function M.build_command(url, opts)
  local adapter, err = M.get_adapter(url)
  if not adapter then
    return nil, err
  end
  
  local parsed, parse_err = adapter.parse_url(url)
  if not parsed then
    return nil, parse_err
  end
  
  return adapter.build_command(parsed, opts or {})
end

-- Format query results
function M.format_results(url, output, opts)
  local adapter, err = M.get_adapter(url)
  if not adapter then
    return output -- Return raw output if no adapter
  end
  
  return adapter.format_results(output, opts or {})
end

-- Test connection
function M.test_connection(url)
  local adapter, err = M.get_adapter(url)
  if not adapter then
    return false, err
  end
  
  local parsed, parse_err = adapter.parse_url(url)
  if not parsed then
    return false, parse_err
  end
  
  if adapter.test_connection then
    return adapter.test_connection(parsed)
  end
  
  -- Default: try to build command as a connection test
  local cmd, cmd_err = adapter.build_command(parsed, { test = true })
  return cmd ~= nil, cmd_err
end

-- Get list of available adapters
function M.available_adapters()
  local schemes = {}
  for scheme, _ in pairs(M.adapters) do
    table.insert(schemes, scheme)
  end
  table.sort(schemes)
  return schemes
end

return M

