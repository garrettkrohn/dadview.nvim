# DadView 🗃️

A modern, pure Lua database UI for Neovim. Browse connections, execute queries, and view results - all without leaving your editor.

## ✨ Features

- 🚀 **Pure Lua Implementation** - No external dependencies, uses Neovim's native async job API
- 🔌 **Pluggable Adapter System** - Easy to add new database support
- 💾 **PostgreSQL Support** - Built-in PostgreSQL adapter (more coming soon!)
- 🎨 **Beautiful UI** - Clean sidebar for managing connections
- ⚡ **Async Query Execution** - Non-blocking queries with progress indicators
- 🎯 **Connection Testing** - Validates connections before use
- 🛑 **Query Cancellation** - Cancel long-running queries with `<C-c>`
- 📊 **Result Buffers** - Dedicated buffers for query results
- 🔄 **Auto-execute on Save** - Optional auto-execution when saving query buffers

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

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

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/dadview',
  config = function()
    require('dadview').setup()
  end
}
```

## 🚀 Quick Start

### 1. Configure Database Connections

Add your database connections to your Neovim config:

```lua
vim.g.dbs = {
  {
    name = 'local_dev',
    url = 'postgresql://user:password@localhost:5432/mydb',
  },
  {
    name = 'production',
    url = 'postgresql://user:password@prod.example.com:5432/proddb',
  },
  {
    name = 'oracle_dev',
    url = 'jdbc:oracle:thin:@hostname:1521/service_name?user=username&password=password',
  },
}
```

### 2. Open DadView

Use `:DadView` or your configured keymap to open the sidebar.

### 3. Connect to a Database

- Press `<CR>` on a connection in the sidebar, or
- Use `:DadView <connection_name>` to connect directly

### 4. Write and Execute Queries

DadView will automatically open a query buffer. Write your SQL and:
- Press `<leader>r` or `<C-CR>` to execute
- Press `<C-c>` to cancel a running query
- Save the buffer (`:w`) to auto-execute (if enabled)

## 📖 Usage

### Commands

| Command | Description |
|---------|-------------|
| `:DadView [connection]` | Toggle sidebar or connect to named connection |
| `:DadViewToggle` | Toggle the sidebar |
| `:DadViewConnect <name>` | Connect to a database by name |
| `:DadViewNewQuery` | Open a new query buffer |
| `:DadViewExecute` | Execute the current query buffer |
| `:DadViewCancel` | Cancel the current running query |
| `:DadViewClose` | Close the sidebar |

### Default Keymaps (in query buffers)

| Key | Action |
|-----|--------|
| `<leader>r` | Execute query |
| `<C-CR>` | Execute query |
| `<C-c>` | Cancel running query |

### Sidebar Keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Connect to database under cursor |
| `R` | Refresh connection list |
| `?` | Show help |
| `q` | Close sidebar |

## ⚙️ Configuration

```lua
require('dadview').setup({
  -- Sidebar width
  width = 40,
  
  -- Sidebar position ('left' or 'right')
  position = 'left',
  
  -- Result buffer split direction ('horizontal' or 'vertical')
  result_split = 'horizontal',
  
  -- Automatically open query buffer when connecting
  auto_open_query_buffer = true,
  
  -- Reuse most recent query file instead of creating new ones
  reuse_query_buffer = false,
  
  -- Auto-execute query when saving buffer
  auto_execute_on_save = true,
})
```

### Setting up Keymaps

```lua
-- Toggle sidebar
vim.keymap.set('n', '<leader>db', '<cmd>DadView<cr>', { desc = 'Toggle DadView' })

-- Quick connect to specific databases
vim.keymap.set('n', '<leader>dl', '<cmd>DadView local<cr>', { desc = 'Connect to local DB' })
vim.keymap.set('n', '<leader>dd', '<cmd>DadView dev<cr>', { desc = 'Connect to dev DB' })

-- Open new query buffer
vim.keymap.set('n', '<leader>dq', '<cmd>DadViewNewQuery<cr>', { desc = 'New query buffer' })
```

## 🔌 Database Adapters

### Currently Supported

- **PostgreSQL** (`postgresql://` or `postgres://`)
  - Requires: `psql` command-line tool
- **Oracle Database via JDBC** (`jdbc:oracle:thin:@host:port/service` or `jdbc:oracle:thin:@host:port:sid`)
  - Requires: Oracle SQLcl (`sql` command) or SQL*Plus (`sqlplus` command)
  - Credentials can be passed via URL parameters: `?user=username&password=password`

### Adding a New Adapter

DadView uses a pluggable adapter system. To add support for a new database:

1. Create a new adapter file in `lua/dadview/adapters/your_database.lua`
2. Implement the required interface:

```lua
local M = {}

-- Parse connection URL
function M.parse_url(url)
  -- Parse and return connection details
  return {
    scheme = 'your_database',
    host = 'localhost',
    port = 1234,
    user = 'user',
    password = 'pass',
    database = 'dbname',
    params = {},
  }
end

-- Build command for executing queries
function M.build_command(parsed, opts)
  -- Return command array and environment variables
  local cmd = { 'your-db-cli', '--host', parsed.host }
  local env = { YOUR_PASSWORD = parsed.password }
  return cmd, env
end

-- Format query results
function M.format_results(output, opts)
  -- Format the CLI output
  return output
end

-- Optional: Test connection
function M.test_connection(parsed)
  -- Return true/false, error_message
  return true, nil
end

return M
```

3. Register your adapter in `lua/dadview/db.lua`:

```lua
local your_db = require('dadview.adapters.your_database')
adapters.register('your_database', your_db)
```

See `lua/dadview/adapters/postgresql.lua` for a complete example.

## 🏗️ Architecture

```
lua/dadview/
├── init.lua              # Main plugin entry point
├── db.lua                # Database operations (query execution, etc.)
├── adapters/
│   ├── init.lua          # Adapter registry and interface
│   └── postgresql.lua    # PostgreSQL adapter
└── ...
```

### Key Components

- **Adapter System**: Modular architecture for database support
- **Async Query Execution**: Uses `vim.system()` for non-blocking queries
- **Result Management**: Dedicated buffers for query results
- **Connection Pooling**: Efficient connection reuse
- **No Memory Leaks**: Proper cleanup of resources

## 🆚 Comparison with vim-dadbod

DadView was inspired by vim-dadbod but built from scratch in Lua:

| Feature | DadView | vim-dadbod |
|---------|---------|------------|
| Language | Pure Lua | VimScript |
| Dependencies | None | None |
| Memory Leaks | ✅ None | ❌ Known issues |
| Async Queries | ✅ Yes | ⚠️ Limited |
| UI | ✅ Built-in | Requires plugin |
| Adapters | 1 (PostgreSQL) | 18+ databases |

DadView focuses on modern Neovim features and a clean architecture, making it easier to maintain and extend.

## 🤝 Contributing

Contributions are welcome! Especially:

- New database adapters (MySQL, SQLite, MongoDB, etc.)
- UI improvements
- Bug fixes and performance improvements

## 📝 License

MIT

## 🙏 Acknowledgments

- Inspired by [vim-dadbod](https://github.com/tpope/vim-dadbod)
- Built for the Neovim community
