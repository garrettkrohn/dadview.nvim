-- Simple test module for DadView
local M = {}

-- Test URL parsing
function M.test_url_parsing()
  local adapters = require('dadview.adapters')
  
  print('Testing PostgreSQL URL parsing...')
  
  local test_cases = {
    {
      url = 'postgresql://user:pass@localhost:5432/mydb',
      expected = {
        scheme = 'postgresql',
        user = 'user',
        password = 'pass',
        host = 'localhost',
        port = 5432,
        database = 'mydb',
      }
    },
    {
      url = 'postgresql://localhost/mydb',
      expected = {
        scheme = 'postgresql',
        host = 'localhost',
        port = 5432,
        database = 'mydb',
      }
    },
    {
      url = 'postgres://user@host:1234/db',
      expected = {
        scheme = 'postgresql',
        user = 'user',
        host = 'host',
        port = 1234,
        database = 'db',
      }
    },
  }
  
  local passed = 0
  local failed = 0
  
  for i, test in ipairs(test_cases) do
    local parsed, err = adapters.parse_url(test.url)
    
    if not parsed then
      print(string.format('  ❌ Test %d FAILED: %s', i, err))
      failed = failed + 1
    else
      local ok = true
      for key, expected_value in pairs(test.expected) do
        if parsed[key] ~= expected_value then
          print(string.format('  ❌ Test %d FAILED: %s expected %s, got %s',
            i, key, tostring(expected_value), tostring(parsed[key])))
          ok = false
          break
        end
      end
      
      if ok then
        print(string.format('  ✅ Test %d PASSED', i))
        passed = passed + 1
      else
        failed = failed + 1
      end
    end
  end
  
  print(string.format('\nResults: %d passed, %d failed', passed, failed))
  return failed == 0
end

-- Test command building
function M.test_command_building()
  local adapters = require('dadview.adapters')
  
  print('\nTesting PostgreSQL command building...')
  
  local url = 'postgresql://testuser:testpass@localhost:5432/testdb'
  local cmd, env = adapters.build_command(url, { test = true })
  
  if not cmd then
    print('  ❌ FAILED: Could not build command')
    return false
  end
  
  print('  Command:', vim.inspect(cmd))
  print('  Environment:', vim.inspect(env))
  
  -- Check for required elements
  local has_psql = cmd[1] == 'psql'
  local has_password = env and env.PGPASSWORD == 'testpass'
  
  if has_psql and has_password then
    print('  ✅ PASSED')
    return true
  else
    print('  ❌ FAILED')
    return false
  end
end

-- Test adapter registry
function M.test_adapter_registry()
  local adapters = require('dadview.adapters')
  
  print('\nTesting adapter registry...')
  
  local available = adapters.available_adapters()
  print('  Available adapters:', vim.inspect(available))
  
  local has_postgresql = vim.tbl_contains(available, 'postgresql')
  local has_postgres = vim.tbl_contains(available, 'postgres')
  
  if has_postgresql and has_postgres then
    print('  ✅ PASSED')
    return true
  else
    print('  ❌ FAILED: Missing PostgreSQL adapter')
    return false
  end
end

-- Run all tests
function M.run_all()
  print('=== DadView Test Suite ===\n')
  
  local results = {
    M.test_adapter_registry(),
    M.test_url_parsing(),
    M.test_command_building(),
  }
  
  local all_passed = true
  for _, result in ipairs(results) do
    if not result then
      all_passed = false
      break
    end
  end
  
  print('\n=== Test Suite Complete ===')
  if all_passed then
    print('✅ All tests passed!')
  else
    print('❌ Some tests failed')
  end
  
  return all_passed
end

return M

