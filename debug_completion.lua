-- Debug script for dadview completion
-- Run this in a dadview query buffer with: :luafile debug_completion.lua

local function print_header(text)
  print('\n=== ' .. text .. ' ===')
end

local function print_check(name, value, expected)
  local status = value and '✓' or '✗'
  print(string.format('%s %s: %s', status, name, vim.inspect(value)))
  if expected and value ~= expected then
    print(string.format('  Expected: %s', vim.inspect(expected)))
  end
end

print_header('Buffer Checks')
local bufnr = vim.api.nvim_get_current_buf()
print_check('Current buffer', bufnr)
print_check('Buffer filetype', vim.bo.filetype, 'sql')
print_check('dadview_query_buffer', vim.b.dadview_query_buffer, true)
print_check('vim.b.db', vim.b.db)
print_check('vim.g.db', vim.g.db)

print_header('DadView State')
local ok, state = pcall(require, 'dadview.state')
if ok then
  print_check('State loaded', true)
  print_check('Current connection', state.state.current_connection and state.state.current_connection.name)
  print_check('Connection URL', state.state.current_connection and state.state.current_connection.url)
else
  print_check('State loaded', false)
  print('  Error: ' .. state)
end

print_header('Completion Module')
local ok, completion = pcall(require, 'dadview.completion')
if ok then
  print_check('Completion module loaded', true)
else
  print_check('Completion module loaded', false)
  print('  Error: ' .. completion)
end

print_header('Blink Source')
local ok, blink_source = pcall(require, 'dadview.completion.blink')
if ok then
  print_check('Blink source loaded', true)
  print_check('Source name', blink_source.name, 'dadview')

  local instance = blink_source.new()
  if instance then
    print_check('Instance created', true)

    -- Test enabled
    local enabled = instance:enabled()
    print_check('Source enabled', enabled, true)

    if not enabled then
      print('  Reasons why it might be disabled:')
      print('    - vim.b.dadview_query_buffer not set')
      print('    - No database URL found (vim.b.db or vim.g.db)')
      print('    - completion.enabled = false in config')
    end

    -- Test trigger characters
    local triggers = instance:get_trigger_characters()
    print_check('Trigger characters', triggers)
  end
else
  print_check('Blink source loaded', false)
  print('  Error: ' .. blink_source)
end

print_header('Blink.cmp Configuration')
local ok, blink_config = pcall(function()
  return require('blink.cmp.config')
end)
if ok then
  print_check('Blink.cmp loaded', true)

  if blink_config.sources and blink_config.sources.providers then
    local dadview_provider = blink_config.sources.providers.dadview
    print_check('DadView provider registered', dadview_provider ~= nil)
    if dadview_provider then
      print('  Provider config:')
      print(vim.inspect(dadview_provider))
    end
  end

  if blink_config.sources and blink_config.sources.default then
    local in_default = vim.tbl_contains(blink_config.sources.default, 'dadview')
    print_check('DadView in default sources', in_default, true)
    print('  Default sources: ' .. vim.inspect(blink_config.sources.default))
  end
else
  print_check('Blink.cmp loaded', false)
  print('  Error: ' .. (blink_config or 'unknown'))
end

print_header('Completion Config')
local ok, config = pcall(require, 'dadview.config')
if ok and config.config.completion then
  print('Completion config:')
  print(vim.inspect(config.config.completion))
else
  print('Could not load dadview config')
end

print_header('Test Context Detection')
local ok, context = pcall(require, 'dadview.completion.context')
if ok then
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  print('Current line: ' .. line)
  print('Cursor position: ' .. col)

  local ctx_type, ctx_info = context.get_context(bufnr, vim.api.nvim_win_get_cursor(0)[1], col)
  print_check('Context type', ctx_type)
  print_check('Context info', ctx_info)
end

print_header('Manual Completion Test')
print('Try these commands:')
print('  1. :lua require("blink.cmp").show()')
print('  2. Type some SQL and press <C-Space>')
print('  3. :lua print(vim.inspect(require("blink.cmp").get_current_context()))')

print('\nIf completion still not working, check:')
print('  1. Is blink.cmp actually running? :lua print(vim.inspect(require("blink.cmp")))')
print('  2. Check blink.cmp logs: :messages')
print('  3. Check if any errors: :checkhealth')
