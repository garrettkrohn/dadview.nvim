# DadView Quick Reference

## Installation

```lua
{ 'your-username/dadview', config = function() require('dadview').setup() end }
```

## Configuration

```lua
vim.g.dbs = {
  { name = 'local', url = 'postgresql://user:pass@localhost:5432/db' },
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:DadView` | Toggle sidebar |
| `:DadView <name>` | Connect to database |
| `:DadViewExecute` | Execute query |
| `:DadViewCancel` | Cancel query |
| `:DadViewNewQuery` | New query buffer |

## Keymaps

### Sidebar
- `<CR>` - Connect
- `R` - Refresh
- `?` - Help
- `q` - Close

### Query Buffer
- `<leader>r` - Execute
- `<C-CR>` - Execute
- `<C-c>` - Cancel

## Connection URL Format

```
postgresql://[user]:[password]@[host]:[port]/[database]
```

## Workflow

1. `:DadView` - Open sidebar
2. `<CR>` - Connect to database
3. Write SQL in query buffer
4. `<leader>r` - Execute
5. View results in result buffer

## Tips

- Save query buffer (`:w`) to auto-execute
- Press `<C-c>` to cancel long queries
- Each query gets its own result buffer
- Connection testing happens automatically

## Troubleshooting

```vim
" Test connection
:lua print(vim.inspect(require('dadview.db').test_connection(vim.g.db)))

" Run tests
:lua require('dadview.test').run_all()

" Check messages
:messages
```

## Adding Databases

Currently supported: **PostgreSQL**

Want more? Create an adapter in `lua/dadview/adapters/yourdb.lua`

See README.md for adapter API.

