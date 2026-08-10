# SQL Completion in dadview.nvim

dadview.nvim provides built-in SQL completion support for [blink.cmp](https://github.com/Saghen/blink.cmp).

## Features

- **Table Completion**: Complete table names after `FROM`, `JOIN`, `UPDATE`, etc.
- **Column Completion**: Complete column names when typing `table.` or `schema.table.`
- **Schema Completion**: Complete schema names in supported contexts
- **SQL Keywords**: Complete SQL reserved keywords (SELECT, WHERE, etc.)
- **Smart Caching**: Metadata is cached for 5 minutes by default to reduce database queries
- **Async Fetching**: Database metadata is fetched asynchronously to avoid blocking

## Supported Databases

- ✅ **PostgreSQL** - Full support (tables, columns, schemas, keywords)
- ✅ **Oracle (JDBC)** - Full support (tables, columns, schemas, keywords)

## Setup

### 1. Install blink.cmp

```lua
-- Using lazy.nvim
{
  'Saghen/blink.cmp',
  dependencies = 'rafamadriz/friendly-snippets',
  version = 'v0.*',
}
```

### 2. Configure blink.cmp to use dadview source

```lua
require('blink.cmp').setup({
  sources = {
    providers = {
      -- Add dadview as a completion source
      dadview = {
        name = "dadview",
        module = "dadview.completion.blink",
        score_offset = 10, -- Optional: prioritize dadview completions
      },
    },
    -- Optional: Configure when dadview is enabled
    default = { 'lsp', 'path', 'snippets', 'buffer', 'dadview' },
  },
})
```

### 3. Configure dadview completion (optional)

```lua
require('dadview').setup({
  -- ... other config ...
  completion = {
    enabled = true,              -- Enable completion (default: true)
    cache_ttl = 300,             -- Cache lifetime in seconds (default: 300)
    keywords_case = "upper",     -- Keyword case: "upper", "lower", "mixed" (default: "upper")
    trigger_characters = { '"', "'", '`', '[', ']', '.', ' ' },
  },
})
```

## Usage

Once configured, completion works automatically in dadview query buffers:

1. **Connect to a database**: `:DadView my_connection`
2. **Open a query buffer**: The completion source activates automatically
3. **Type SQL queries**: Completion triggers based on context

### Examples

```sql
-- Table completion (after FROM, JOIN, etc.)
SELECT * FROM use<Tab>
-- Suggests: users, user_profiles, etc.

-- Column completion (after table.)
SELECT users.<Tab>
-- Suggests: id, name, email, etc.

-- Schema-qualified tables
SELECT * FROM public.<Tab>
-- Suggests: users, products, orders, etc.

-- SQL keywords
SEL<Tab>
-- Suggests: SELECT

WH<Tab>
-- Suggests: WHERE, WHEN
```

## How It Works

### Context Detection

The completion system detects the current SQL context:

- **Column context**: Triggered by `table.` or `schema.table.`
- **Table context**: Triggered after keywords like `FROM`, `JOIN`, `UPDATE`, `INTO`
- **Keyword context**: Default fallback for SQL keywords

### Caching

Metadata is cached per database connection:

- **Tables**: Cached for the entire connection
- **Columns**: Cached per table (keyed by `schema.table`)
- **Schemas**: Cached for the entire connection
- **TTL**: 5 minutes by default (configurable via `cache_ttl`)

To invalidate the cache:

```lua
require('dadview.completion').invalidate_cache(db_url)
-- Or invalidate all caches:
require('dadview.completion').invalidate_cache()
```

## Configuration Reference

### completion.enabled

- **Type**: `boolean`
- **Default**: `true`
- **Description**: Enable or disable SQL completion globally

### completion.cache_ttl

- **Type**: `number`
- **Default**: `300` (5 minutes)
- **Description**: How long to cache database metadata (in seconds)

### completion.keywords_case

- **Type**: `"upper" | "lower" | "mixed"`
- **Default**: `"upper"`
- **Description**: Case style for SQL keywords
  - `"upper"`: SELECT, FROM, WHERE
  - `"lower"`: select, from, where
  - `"mixed"`: Select, From, Where

### completion.trigger_characters

- **Type**: `table` (list of strings)
- **Default**: `{ '"', "'", '`', '[', ']', '.', ' ' }`
- **Description**: Characters that trigger completion automatically

## Troubleshooting

### Completion not working

1. **Check buffer type**: Ensure you're in a dadview query buffer
   ```lua
   :lua print(vim.b.dadview_query_buffer)  -- Should print 'true'
   ```

2. **Check database connection**: Ensure vim.b.db is set
   ```lua
   :lua print(vim.b.db)  -- Should print your database URL
   ```

3. **Check blink.cmp source**: Ensure dadview source is registered
   ```lua
   :lua print(vim.inspect(require('blink.cmp.config').sources.providers.dadview))
   ```

### No tables/columns appearing

1. **Check adapter support**: Ensure your adapter implements completion methods
   ```lua
   :lua print(vim.inspect(require('dadview.adapters').get_adapter('postgresql://...')))
   ```

2. **Check database permissions**: Ensure your database user can query metadata tables
   - PostgreSQL: `information_schema.tables`, `information_schema.columns`
   - Oracle: `all_tables`, `all_tab_columns`, `all_users`

3. **Clear cache**: Try invalidating the cache
   ```lua
   :lua require('dadview.completion').invalidate_cache()
   ```

### Slow completion

- Reduce `cache_ttl` to cache metadata longer
- Check database performance for metadata queries
- Consider adding indexes on metadata tables (if you have many tables)

## Comparison with vim-dadbod-completion

| Feature | dadview.nvim | vim-dadbod-completion |
|---------|-------------|---------------------|
| Tables | ✅ | ✅ |
| Columns | ✅ | ✅ |
| Schemas | ✅ | ✅ |
| Keywords | ✅ | ✅ |
| Aliases | ❌ (future) | ✅ |
| Functions | ❌ (future) | ✅ |
| Bind parameters | ❌ | ✅ |
| Implementation | Pure Lua | VimScript + Lua |
| Completion framework | blink.cmp only | Multiple (nvim-cmp, vim-lsp, etc.) |

## Future Enhancements

- [ ] Alias parsing (`FROM users u` → complete `u.`)
- [ ] Function completion (database-specific functions)
- [ ] View completion
- [ ] Trigger/procedure completion
- [ ] Multi-completion framework support (nvim-cmp, coq, etc.)
