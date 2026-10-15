-- nvim --headless -u NONE -i NONE -l tests/parameters.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local ok, err = xpcall(function()
  local parameters = require("dbee.parameters")
  local buffer = vim.api.nvim_create_buf(true, false)
  local calls, prompts = {}, 0
  local handler = {
    connection_parameters = function(_, _, query)
      if query == "plain" then
        return {}
      end
      if query == "invalid" then
        error("invalid bound batch")
      end
      return { "id", "text", "nothing" }
    end,
    connection_execute = function(_, id, query)
      calls[#calls + 1] = { id = id, query = query }
      return calls[#calls]
    end,
    connection_execute_bound = function(_, id, query, values)
      calls[#calls + 1] = { id = id, query = query, values = values }
      return calls[#calls]
    end,
  }
  local values = {
    id = { text = "9007199254740993", is_null = false },
    text = { text = "O'Reilly", is_null = false },
    nothing = { text = "", is_null = true },
  }
  local defaults_seen
  parameters.prompt = function(names, defaults, callback)
    prompts = prompts + 1
    assert(#names == 3)
    defaults_seen = defaults
    callback(vim.deepcopy(values))
  end
  local function run(connection, query)
    parameters.run(handler, connection, query or "SELECT :id, :text, :nothing", buffer, function() end)
  end
  run("first")
  assert(vim.tbl_isempty(defaults_seen) and prompts == 1)
  assert(calls[1].query == "SELECT :id, :text, :nothing")
  assert(calls[1].values.text.text == "O'Reilly" and calls[1].values.nothing.is_null)
  run("first")
  assert(prompts == 2 and defaults_seen.id.text == "9007199254740993")
  run("second")
  assert(vim.tbl_isempty(defaults_seen), "Values must be isolated by connection")
  parameters.prompt = function(_, _, callback)
    callback(nil)
  end
  local before = #calls
  run("first")
  assert(#calls == before, "Cancellation must not execute")
  local notify = vim.notify
  vim.notify = function() end
  run("first", "invalid")
  assert(#calls == before)
  run("first", "plain")
  assert(#calls == before + 1 and calls[#calls].values == nil)
  vim.api.nvim_buf_delete(buffer, { force = true })
  vim.notify = notify
  print("PASS: prompt defaults, exact values, NULL, cancellation, validation, plain-query bypass")
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
