-- Simple manual test for SQL completion
-- Run this in Neovim with: :luafile tests/completion_test.lua

local function test_keywords()
  print('Testing SQL keywords...')
  local keywords = require('dadview.completion.keywords')

  local upper = keywords.get_keywords('upper')
  assert(#upper > 0, 'Should have keywords')
  assert(upper[1] == 'SELECT', 'First keyword should be SELECT')
  print('✓ Keywords (upper): ' .. #upper .. ' keywords')

  local lower = keywords.get_keywords('lower')
  assert(lower[1] == 'select', 'Lower case should work')
  print('✓ Keywords (lower): ' .. #lower .. ' keywords')

  print('')
end

local function test_context()
  print('Testing context detection...')
  local context = require('dadview.completion.context')

  -- Test column context
  local is_col, info = context.is_column_context('SELECT users.')
  assert(is_col == true, 'Should detect column context')
  assert(info.table == 'users', 'Should extract table name')
  print('✓ Column context: users.')

  -- Test schema.table context
  is_col, info = context.is_column_context('SELECT public.users.')
  assert(is_col == true, 'Should detect schema.table context')
  assert(info.schema == 'public', 'Should extract schema')
  assert(info.table == 'users', 'Should extract table')
  print('✓ Column context: public.users.')

  -- Test table context
  local is_tbl = context.is_table_context('SELECT * FROM ')
  assert(is_tbl == true, 'Should detect table context after FROM')
  print('✓ Table context: FROM ')

  is_tbl = context.is_table_context('JOIN ')
  assert(is_tbl == true, 'Should detect table context after JOIN')
  print('✓ Table context: JOIN ')

  print('')
end

local function test_schemas()
  print('Testing schema modules...')

  -- PostgreSQL
  local pg = require('dadview.completion.schemas.postgresql')
  local query = pg.get_tables_query()
  assert(query:match('information_schema'), 'Should query information_schema')
  print('✓ PostgreSQL tables query')

  query = pg.get_columns_query('public', 'users')
  assert(query:match('public'), 'Should include schema')
  assert(query:match('users'), 'Should include table')
  print('✓ PostgreSQL columns query')

  -- Oracle
  local oracle = require('dadview.completion.schemas.oracle')
  query = oracle.get_tables_query()
  assert(query:match('all_tables'), 'Should query all_tables')
  print('✓ Oracle tables query')

  query = oracle.get_columns_query('SCOTT', 'EMP')
  assert(query:match('SCOTT'), 'Should include schema')
  assert(query:match('EMP'), 'Should include table')
  print('✓ Oracle columns query')

  print('')
end

local function test_cache()
  print('Testing cache manager...')
  local cache = require('dadview.completion')

  -- Invalidate cache
  cache.invalidate_cache()
  print('✓ Cache invalidated')

  -- Test that cached values are nil initially
  local tables = cache.get_cached_tables('postgresql://test')
  assert(tables == nil, 'Cache should be empty initially')
  print('✓ Cache empty initially')

  print('')
end

local function test_blink_source()
  print('Testing blink.cmp source...')
  local source = require('dadview.completion.blink')

  assert(source.name == 'dadview', 'Source name should be dadview')
  print('✓ Source name: ' .. source.name)

  local instance = source.new()
  assert(instance ~= nil, 'Should create instance')
  print('✓ Source instance created')

  -- Test trigger characters
  local triggers = instance:get_trigger_characters()
  assert(type(triggers) == 'table', 'Should return table')
  assert(#triggers > 0, 'Should have trigger characters')
  print('✓ Trigger characters: ' .. #triggers .. ' chars')

  print('')
end

-- Run all tests
print('=== DadView Completion Tests ===\n')

local success, err = pcall(test_keywords)
if not success then
  print('✗ Keywords test failed: ' .. err)
end

success, err = pcall(test_context)
if not success then
  print('✗ Context test failed: ' .. err)
end

success, err = pcall(test_schemas)
if not success then
  print('✗ Schema test failed: ' .. err)
end

success, err = pcall(test_cache)
if not success then
  print('✗ Cache test failed: ' .. err)
end

success, err = pcall(test_blink_source)
if not success then
  print('✗ Blink source test failed: ' .. err)
end

print('=== All tests completed ===')
