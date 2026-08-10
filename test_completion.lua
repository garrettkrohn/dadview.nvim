-- Test script for DadView completion
-- Run this in Neovim with :luafile %

print("=== Testing DadView Completion ===")

-- Check if blink is available
local blink_ok, blink = pcall(require, 'blink.cmp')
print("Blink available: " .. tostring(blink_ok))

-- Check if the dadview completion module loads
local dadview_ok, dadview_completion = pcall(require, 'dadview.completion.blink')
print("DadView completion module loads: " .. tostring(dadview_ok))
if not dadview_ok then
  print("Error: " .. tostring(dadview_completion))
  return
end

-- Check if blink.cmp.types exists
local types_ok, types = pcall(require, 'blink.cmp.types')
print("Blink types available: " .. tostring(types_ok))
if types_ok then
  print("CompletionItemKind.Keyword: " .. tostring(types.CompletionItemKind.Keyword))
else
  print("Error: " .. tostring(types))
end

-- Create a test instance
local source = dadview_completion.new()
print("\nSource created: " .. tostring(source))

-- Check current buffer
local bufnr = vim.api.nvim_get_current_buf()
print("\nCurrent buffer: " .. bufnr)
print("Is dadview_query_buffer: " .. tostring(vim.b[bufnr].dadview_query_buffer))
print("vim.b.db: " .. tostring(vim.b[bufnr].db))
print("vim.g.db: " .. tostring(vim.g.db))

-- Test if source is enabled
print("\nSource enabled: " .. tostring(source:enabled()))

-- Get trigger characters
if source.get_trigger_characters then
  local triggers = source:get_trigger_characters()
  print("Trigger characters: " .. vim.inspect(triggers))
end

print("\n=== Test Complete ===")
