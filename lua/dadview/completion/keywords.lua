local M = {}

-- SQL reserved keywords (comprehensive list from SQL standard + common extensions)
M.keywords = {
  -- Core SQL keywords
  'SELECT', 'FROM', 'WHERE', 'GROUP BY', 'ORDER BY', 'HAVING', 'LIMIT', 'OFFSET',
  'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE', 'TRUNCATE',
  'CREATE', 'ALTER', 'DROP', 'RENAME',
  'TABLE', 'VIEW', 'INDEX', 'SEQUENCE', 'SCHEMA', 'DATABASE',
  'CONSTRAINT', 'PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'CHECK', 'DEFAULT',
  'NOT NULL', 'NULL', 'AUTO_INCREMENT',

  -- JOIN types
  'JOIN', 'INNER JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'FULL JOIN', 'CROSS JOIN',
  'LEFT OUTER JOIN', 'RIGHT OUTER JOIN', 'FULL OUTER JOIN',
  'NATURAL JOIN', 'ON', 'USING',

  -- Set operations
  'UNION', 'UNION ALL', 'INTERSECT', 'EXCEPT', 'MINUS',

  -- Subquery keywords
  'IN', 'NOT IN', 'EXISTS', 'NOT EXISTS', 'ANY', 'ALL', 'SOME',

  -- Logical operators
  'AND', 'OR', 'NOT', 'BETWEEN', 'LIKE', 'ILIKE', 'IS', 'IS NOT',

  -- Aggregate functions
  'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'STDDEV', 'VARIANCE',
  'STRING_AGG', 'ARRAY_AGG', 'JSON_AGG', 'JSONB_AGG',

  -- Window functions
  'OVER', 'PARTITION BY', 'ROW_NUMBER', 'RANK', 'DENSE_RANK',
  'LAG', 'LEAD', 'FIRST_VALUE', 'LAST_VALUE', 'NTH_VALUE',
  'ROWS', 'RANGE', 'PRECEDING', 'FOLLOWING', 'UNBOUNDED', 'CURRENT ROW',

  -- Common functions
  'CAST', 'CONVERT', 'COALESCE', 'NULLIF', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
  'CONCAT', 'SUBSTRING', 'TRIM', 'LOWER', 'UPPER', 'LENGTH',
  'NOW', 'CURRENT_TIMESTAMP', 'CURRENT_DATE', 'CURRENT_TIME',
  'EXTRACT', 'DATE_TRUNC', 'TO_CHAR', 'TO_DATE', 'TO_TIMESTAMP',

  -- Data types
  'INTEGER', 'INT', 'BIGINT', 'SMALLINT', 'NUMERIC', 'DECIMAL', 'REAL', 'DOUBLE PRECISION',
  'VARCHAR', 'CHAR', 'TEXT', 'BOOLEAN', 'DATE', 'TIME', 'TIMESTAMP', 'INTERVAL',
  'UUID', 'JSON', 'JSONB', 'ARRAY', 'BYTEA',

  -- Transaction control
  'BEGIN', 'COMMIT', 'ROLLBACK', 'SAVEPOINT', 'TRANSACTION',
  'START TRANSACTION', 'SET TRANSACTION',

  -- Access control
  'GRANT', 'REVOKE', 'PRIVILEGES', 'ROLE', 'USER',

  -- Other common keywords
  'AS', 'DISTINCT', 'ALL', 'ASC', 'DESC', 'NULLS FIRST', 'NULLS LAST',
  'WITH', 'RECURSIVE', 'RETURNING',
  'FOR', 'SHARE', 'UPDATE', 'KEY SHARE', 'NO KEY UPDATE',
  'COLLATE', 'CASCADE', 'RESTRICT', 'NO ACTION', 'SET NULL', 'SET DEFAULT',
  'DEFERRABLE', 'INITIALLY DEFERRED', 'INITIALLY IMMEDIATE',
  'MATERIALIZED', 'REFRESH', 'CONCURRENTLY',
  'IF EXISTS', 'IF NOT EXISTS',
  'TEMP', 'TEMPORARY', 'UNLOGGED', 'LOGGED',
  'GENERATED', 'ALWAYS', 'BY DEFAULT', 'IDENTITY',
  'INHERITS', 'EXCLUDING', 'INCLUDING',
  'ANALYZE', 'VACUUM', 'EXPLAIN', 'DESCRIBE',

  -- PostgreSQL specific
  'LATERAL', 'TABLESAMPLE', 'BERNOULLI', 'SYSTEM',
  'FETCH', 'FIRST', 'NEXT', 'ONLY',
  'SIMILAR TO', 'DISTINCT ON',
  'PERFORM', 'RAISE', 'NOTICE', 'EXCEPTION',

  -- Oracle specific
  'DUAL', 'SYSDATE', 'ROWNUM', 'ROWID',
  'CONNECT BY', 'START WITH', 'PRIOR',
  'DECODE', 'NVL', 'NVL2',

  -- Window frame keywords
  'GROUPS', 'EXCLUDE', 'CURRENT', 'TIES', 'NO OTHERS',
}

-- Get keywords in specified case
function M.get_keywords(case_style)
  case_style = case_style or 'upper'

  if case_style == 'lower' then
    local lower_keywords = {}
    for _, kw in ipairs(M.keywords) do
      table.insert(lower_keywords, kw:lower())
    end
    return lower_keywords
  elseif case_style == 'upper' then
    return M.keywords
  else
    -- Mixed case: capitalize first letter of each word
    local mixed_keywords = {}
    for _, kw in ipairs(M.keywords) do
      local parts = {}
      for word in kw:gmatch('%S+') do
        table.insert(parts, word:sub(1,1):upper() .. word:sub(2):lower())
      end
      table.insert(mixed_keywords, table.concat(parts, ' '))
    end
    return mixed_keywords
  end
end

return M
