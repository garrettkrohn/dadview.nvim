# DadView Setup Guide

## Quick Setup

### 1. Installation

Add to your Neovim config (using lazy.nvim):

```lua
{
  'your-username/dadview',
  config = function()
    require('dadview').setup({
      width = 40,
      position = 'left',
      auto_open_query_buffer = true,
      auto_execute_on_save = true,
    })
  end
}
```

### 2. Configure Database Connections

Add this to your init.lua or anywhere in your config:

```lua
-- Helper function for password management (optional)
local function get_password(key)
  -- Option 1: Use a password manager
  -- return vim.fn.system('pass show ' .. key):gsub('\n', '')
  
  -- Option 2: Use environment variables
  -- return vim.env[key]
  
  -- Option 3: Hardcode (not recommended for production)
  return 'your_password_here'
end

-- Define your database connections
vim.g.dbs = {
  {
    name = 'local_dev',
    url = string.format(
      'postgresql://user:%s@localhost:5432/mydb',
      get_password('LOCAL_DB_PASSWORD')
    ),
  },
  {
    name = 'staging',
    url = 'postgresql://user:password@staging.example.com:5432/mydb',
  },
}
```

### 3. Set Up Keymaps

```lua
-- Main commands
vim.keymap.set('n', '<leader>db', '<cmd>DadView<cr>', { desc = 'Toggle DadView' })
vim.keymap.set('n', '<leader>dq', '<cmd>DadViewNewQuery<cr>', { desc = 'New Query' })

-- Quick connect shortcuts
vim.keymap.set('n', '<leader>dl', '<cmd>DadView local<cr>', { desc = 'Connect: Local' })
vim.keymap.set('n', '<leader>ds', '<cmd>DadView staging<cr>', { desc = 'Connect: Staging' })
```

## PostgreSQL Connection URL Format

```
postgresql://[user]:[password]@[host]:[port]/[database]?[params]
```

### Examples

```lua
-- Basic connection
url = 'postgresql://postgres:password@localhost:5432/mydb'

-- With SSL
url = 'postgresql://user:pass@host:5432/db?sslmode=require'

-- SSH tunnel
url = 'postgresql://user:pass@localhost:5433/db'  -- forwarded port

-- Default user (current OS user)
url = 'postgresql://localhost/mydb'

-- Default database (same as user)
url = 'postgresql://localhost'
```

## Workflow

### Basic Query Execution

1. Open DadView: `<leader>db`
2. Select a connection with `<CR>`
3. Write your SQL in the query buffer
4. Execute with `<leader>r` or `<C-CR>`
5. View results in the automatically opened result buffer

### Managing Multiple Queries

Each query buffer gets its own result buffer:
- `query_local_dev_20240113_143022.sql` → `query_local_dev_20240113_143022.dbout`
- Result buffers are linked to their query buffers
- You can have multiple query/result pairs open simultaneously

### Cancelling Long-Running Queries

If a query is taking too long:
1. Switch to the query buffer
2. Press `<C-c>` to cancel
3. The result buffer will show cancellation status

## Advanced Configuration

### Auto-execute on Save

Enable automatic query execution when you save:

```lua
require('dadview').setup({
  auto_execute_on_save = true,  -- default: true
})
```

Now when you save a query buffer (`:w`), it automatically executes.

### Custom Keymaps in Query Buffers

The plugin automatically sets up keymaps in query buffers, but you can customize them:

```lua
-- Override in an autocmd
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'sql',
  callback = function(args)
    -- Only for dadview query buffers
    if vim.b[args.buf].dadview_query_buffer then
      vim.keymap.set('n', '<F5>', function()
        require('dadview').execute_query_buffer(args.buf)
      end, { buffer = args.buf, desc = 'Execute Query' })
    end
  end,
})
```

### Password Management

#### Option 1: Password Manager (Recommended)

```lua
local function get_password(key)
  -- Using 'pass' password manager
  local handle = io.popen('pass show ' .. key)
  local password = handle:read('*a'):gsub('\n', '')
  handle:close()
  return password
end

vim.g.dbs = {
  {
    name = 'production',
    url = string.format(
      'postgresql://user:%s@host:5432/db',
      get_password('db/production')
    ),
  },
}
```

#### Option 2: Environment Variables

```lua
vim.g.dbs = {
  {
    name = 'production',
    url = string.format(
      'postgresql://user:%s@host:5432/db',
      vim.env.PROD_DB_PASSWORD or ''
    ),
  },
}
```

Then set in your shell:
```bash
export PROD_DB_PASSWORD='your_password'
```

#### Option 3: Separate Connections File

```lua
-- In init.lua
local connections_file = vim.fn.expand('~/.config/nvim/db-connections.lua')
if vim.fn.filereadable(connections_file) == 1 then
  vim.g.dbs = dofile(connections_file)
end

-- Add to .gitignore
-- echo "db-connections.lua" >> ~/.config/nvim/.gitignore
```

## Troubleshooting

### "psql: command not found"

Install PostgreSQL client tools:

```bash
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt install postgresql-client

# Arch
sudo pacman -S postgresql
```

### Connection Fails

1. Test connection manually:
   ```bash
   psql "postgresql://user:password@host:5432/database"
   ```

2. Check:
   - Is PostgreSQL running?
   - Are credentials correct?
   - Is the host accessible?
   - Is the port correct?
   - Firewall rules?

3. Enable SSL if required:
   ```lua
   url = 'postgresql://user:pass@host:5432/db?sslmode=require'
   ```

### Memory Issues

Unlike vim-dadbod, DadView properly cleans up after queries. However:

- Large result sets consume memory while displayed
- Close result buffers you don't need: `:bd` or `gq` (if mapped)
- Cancel unnecessary running queries: `<C-c>`

### Query Results Not Showing

1. Check for errors in result buffer
2. Verify the query is valid SQL
3. Check `:messages` for error output
4. Try running the query manually in `psql`

## Migration from vim-dadbod

DadView is designed as a replacement for vim-dadbod. Here's what to change:

### Remove vim-dadbod

```lua
-- Remove this from your config:
-- 'tpope/vim-dadbod'
-- 'kristijanhusak/vim-dadbod-ui'  -- if using
-- 'kristijanhusak/vim-dadbod-completion'  -- if using
```

### Update Connection Format

vim-dadbod and DadView use the same connection URL format, so your existing `vim.g.dbs` should work as-is!

### Command Compatibility

DadView includes vim-dadbod-compatible commands:

- `:DB` → Execute query (works in DadView)
- `:%DB` → Execute buffer (works in DadView)

So most of your existing keymaps and workflows should work!

## Tips & Tricks

### Multiple Database Instances

```lua
vim.g.dbs = {
  { name = 'local_app', url = 'postgresql://localhost:5432/app' },
  { name = 'local_analytics', url = 'postgresql://localhost:5432/analytics' },
  { name = 'dev_app', url = 'postgresql://dev.example.com:5432/app' },
}
```

### SSH Tunnels

```lua
-- First, create the tunnel:
-- ssh -L 5433:localhost:5432 user@remote-server

-- Then connect through the tunnel:
vim.g.dbs = {
  {
    name = 'remote_via_tunnel',
    url = 'postgresql://user:pass@localhost:5433/database',
  },
}
```

### Query Templates

Create a templates directory with common queries:

```bash
mkdir -p ~/.config/nvim/sql-templates
```

```sql
-- ~/.config/nvim/sql-templates/users.sql
SELECT * FROM users WHERE created_at > NOW() - INTERVAL '7 days';
```

Then open with:
```vim
:e ~/.config/nvim/sql-templates/users.sql
:set ft=sql
```

## Next Steps

- Check out the [README.md](README.md) for full documentation
- Explore adding new database adapters
- Share your favorite queries and workflows!

## Getting Help

If you run into issues:

1. Check `:checkhealth` for Neovim issues
2. Verify `psql` works independently
3. Check `:messages` for error output
4. Open an issue on GitHub with:
   - Neovim version (`:version`)
   - OS
   - Connection URL format (without credentials!)
   - Error messages
