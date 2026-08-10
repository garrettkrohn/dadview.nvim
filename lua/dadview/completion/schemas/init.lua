local M = {}

-- Registry of schema query modules by database type
M.registry = {
  postgresql = require('dadview.completion.schemas.postgresql'),
  postgres = require('dadview.completion.schemas.postgresql'),
  oracle = require('dadview.completion.schemas.oracle'),
  jdbc = require('dadview.completion.schemas.oracle'), -- JDBC adapter uses Oracle queries
}

-- Get schema module for a database URL
function M.get_module(url)
  if not url then
    return nil
  end

  local scheme = url:match('^([^:]+):')
  if not scheme then
    return nil
  end

  scheme = scheme:lower()
  return M.registry[scheme]
end

return M
