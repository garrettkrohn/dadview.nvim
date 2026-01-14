-- Example configuration for DadView plugin
-- Place this in your Neovim config (e.g., ~/.config/nvim/lua/plugins/dadview.lua)

return {
  'your-username/dadview',
  -- No dependencies required! Pure Lua implementation
  config = function()
    -- Helper function to get passwords (replace with your password manager)
    local function pass(key)
      -- Example: return vim.fn.system('pass show ' .. key):gsub('\n', '')
      -- For now, return placeholder
      return 'YOUR_PASSWORD_HERE'
    end

    -- Configure database connections
    vim.g.dbs = {
      {
        name = 'platform_local',
        url = string.format('postgresql://postgres:%s@localhost:4432/novaapi', 'postgres'),
      },
      {
        name = 'platform_dev',
        url = string.format('postgresql://gkrohn:%s@localhost:1111/novaapi', pass('dev01')),
      },
      {
        name = 'platform_dev_workflow',
        url = string.format('postgresql://gkrohn:%s@localhost:1111/workflow_engine', pass('dev01')),
      },
      {
        name = 'platform_ptx',
        url = string.format('postgresql://gkrohn:%s@localhost:1111/novaapi', pass('ptx01')),
      },
      {
        name = 'platform_prod',
        url = string.format('postgresql://gkrohn:%s@localhost:1111/novaapi', pass('prod01')),
      },
      {
        name = 'platform_prod_workflow_engine',
        url = string.format('postgresql://gkrohn:%s@localhost:1111/workflow_engine', pass('prod01')),
      },
      {
        name = 'ctl_local',
        url = string.format('postgresql://myuser:%s@localhost:1432/warehouse', pass('ctl/local')),
      },
      {
        name = 'ctl_dev',
        url = string.format('postgresql://garrett.krohn:%s@localhost:1111/warehouse', pass('dw01')),
      },
    }

    -- Setup DadView
    require('dadview').setup({
      width = 40,
      position = 'left',
      auto_open_query_buffer = true, -- Automatically open query buffer on connect
      auto_execute_on_save = true,   -- Automatically execute query on save
    })

    -- Optional: Set up keymaps
    vim.keymap.set('n', '<leader>dv', '<cmd>DadView<cr>', { desc = 'Toggle DadView' })
    vim.keymap.set('n', '<leader>dl', '<cmd>DadView local<cr>', { desc = 'Connect to local DB' })
    vim.keymap.set('n', '<leader>dd', '<cmd>DadView dev<cr>', { desc = 'Connect to dev DB' })
    vim.keymap.set('n', '<leader>dp', '<cmd>DadView prod<cr>', { desc = 'Connect to prod DB' })
    vim.keymap.set('n', '<leader>dq', '<cmd>DadViewNewQuery<cr>', { desc = 'New query buffer' })
    
    -- Query execution keymaps (set in query buffers automatically)
    -- <leader>r or <C-CR> - Execute query
    -- <C-c> - Cancel running query
  end,
}

-- Note: This plugin now includes its own database adapters!
-- Currently supported:
--   - PostgreSQL (postgresql://)
-- 
-- Future adapters can be added to lua/dadview/adapters/
