-- Test script to debug sql executable detection
print("Testing sql command detection...")
print("vim.fn.executable('sql'):", vim.fn.executable('sql'))
print("PATH:", vim.env.PATH)
print("")

-- Test what the adapter does
local jdbc = require("dadview.adapters.jdbc")
local parsed = {
  scheme = 'jdbc',
  subprotocol = 'oracle',
  driver = 'thin',
  host = 'chronos-database.services.dev.ourfamilywizard.com',
  port = 1521,
  service_name = 'OFWP',
  user = 'ofw_app',
  password = 'foobar123',
  raw_url = 'jdbc:oracle:thin:@chronos-database.services.dev.ourfamilywizard.com:1521/OFWP',
  params = {},
}

print("Calling jdbc.build_command...")
local cmd, env = jdbc.build_command(parsed, {})
if cmd then
  print("Command built successfully:")
  print("  cmd:", vim.inspect(cmd))
else
  print("Command build failed:")
  print("  error:", env)
end
