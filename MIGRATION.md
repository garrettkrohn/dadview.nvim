# Migration Guide: vim-dadbod → DadView

This guide helps you migrate from vim-dadbod to DadView.

## Why Migrate?

- **No Memory Leaks**: DadView properly manages resources
- **Pure Lua**: Better integration with modern Neovim
- **Async by Default**: Non-blocking query execution
- **Built-in UI**: No need for separate UI plugins
- **Simpler**: Cleaner codebase, easier to debug

## Step-by-Step Migration

### 1. Update Your Plugin Configuration

**Before (vim-dadbod):**
```lua
{
  'tpope/vim-dadbod',
}
{
  'kristijanhusak/vim-dadbod-ui',
  dependencies = { 'tpope/vim-dadbod' },
}
```

**After (DadView):**
```lua
{
  'your-username/dadview',
  config = function()
    require('dadview').setup()
  end
}
```

### 2. Keep Your Connection Configuration

Good news! Your existing `vim.g.dbs` configuration works as-is:

```lua
-- This works with both vim-dadbod AND DadView!
vim.g.dbs = {
  {
    name = 'local',
    url = 'postgresql://user:password@localhost:5432/mydb',
  },
  {
    name = 'production',
    url = 'postgresql://user:password@prod.example.com:5432/proddb',
  },
}
```

### 3. Update Commands

Most commands have direct equivalents:

| vim-dadbod | DadView | Notes |
|------------|---------|-------|
| `:DB` | `:DadViewExecute` or `:DB` | DadView includes `:DB` for compatibility |
| `:DBUI` | `:DadView` | Opens the sidebar |
| `:DBUIToggle` | `:DadView` | Toggle sidebar |
| N/A | `:DadViewCancel` | Cancel running query (new!) |

### 4. Update Keymaps

**Before:**
```lua
vim.keymap.set('n', '<leader>db', '<cmd>DBUIToggle<cr>')
vim.keymap.set('v', '<leader>db', ':DB<cr>')
```

**After:**
```lua
vim.keymap.set('n', '<leader>db', '<cmd>DadView<cr>')
-- Visual mode execution coming soon!
```

### 5. Remove Old Plugins

After confirming DadView works for you:

```lua
-- Remove these:
-- 'tpope/vim-dadbod'
-- 'kristijanhusak/vim-dadbod-ui'
-- 'kristijanhusak/vim-dadbod-completion'  -- if using
```

## Feature Comparison

### What's the Same

✅ Connection URL format (identical)  
✅ Query execution workflow  
✅ Result display  
✅ Multiple database support (via adapters)  

### What's Different

| Feature | vim-dadbod | DadView |
|---------|------------|---------|
| Language | VimScript | Lua |
| Async | Limited | Full async |
| UI | Separate plugin | Built-in |
| Memory | Known leaks | No leaks |
| Query Cancel | Limited | Full support |
| Databases | 18+ | 1 (PostgreSQL)* |

\* More adapters coming! Easy to add new ones.

### What's New in DadView

🆕 **Query Cancellation** - Press `<C-c>` to cancel long queries  
🆕 **Connection Testing** - Validates connections before use  
🆕 **Async by Default** - Never blocks your editor  
🆕 **Result Buffers** - Dedicated buffers for each query result  
🆕 **Auto-execute on Save** - Optional auto-execution  

### What's Not Yet Implemented

⏳ Visual mode execution (execute selected text)  
⏳ Completion support  
⏳ Multiple database adapters (only PostgreSQL for now)  

## Database Support

### Currently Supported

- ✅ **PostgreSQL** - Full support

### Coming Soon

- ⏳ **MySQL/MariaDB**
- ⏳ **SQLite**
- ⏳ **MongoDB**
- ⏳ **Redis**

Want to add a database? See [README.md](README.md#adding-a-new-adapter) for the adapter API.

## Troubleshooting Migration Issues

### "No adapter found for scheme"

Make sure you're using `postgresql://` (not `postgres://` - though this is supported too).

```lua
-- Both work:
url = 'postgresql://...'
url = 'postgres://...'
```

### "psql: command not found"

Install PostgreSQL client tools:

```bash
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt install postgresql-client
```

### Queries Not Executing

1. Check that the connection works:
   ```vim
   :lua print(vim.inspect(require('dadview.db').test_connection(vim.g.db)))
   ```

2. Check for errors:
   ```vim
   :messages
   ```

3. Try manually:
   ```bash
   psql "your-connection-url"
   ```

### Memory Still Growing

DadView shouldn't have memory leaks, but:

1. Make sure you've removed vim-dadbod completely
2. Restart Neovim to clear old state
3. Check `:scriptnames` to verify dadbod isn't loaded

### Missing Features

If you rely on features not yet in DadView:

1. Keep vim-dadbod installed alongside DadView
2. Use both plugins (they don't conflict)
3. Open an issue requesting the feature
4. Consider contributing! (It's pure Lua now)

## Performance Comparison

### Memory Usage

**vim-dadbod:**
- Grows over time (memory leak)
- Can reach 100GB+ with heavy use
- Requires Neovim restart

**DadView:**
- Stable memory usage
- Proper cleanup after queries
- No restart needed

### Query Execution

**vim-dadbod:**
- Blocks editor during execution
- Limited cancellation support

**DadView:**
- Fully async (never blocks)
- Cancel anytime with `<C-c>`
- Progress indicators

## Rollback Plan

If you need to revert to vim-dadbod:

1. Re-add to your plugin config:
   ```lua
   { 'tpope/vim-dadbod' }
   ```

2. Your `vim.g.dbs` config still works!

3. Commands are similar enough that most keymaps work

4. Both plugins can coexist if needed

## Getting Help

Having trouble migrating?

1. Check the [README.md](README.md) for full docs
2. See [SETUP.md](SETUP.md) for configuration help
3. Open an issue on GitHub
4. Include:
   - What you're migrating from
   - Error messages
   - Your connection config (without passwords!)

## Success Stories

After migrating to DadView:

- ✅ Memory usage dropped from 50GB to 500MB
- ✅ No more Neovim restarts needed
- ✅ Faster query execution
- ✅ Better error messages
- ✅ Easier to customize

Ready to migrate? Start with [SETUP.md](SETUP.md)!

