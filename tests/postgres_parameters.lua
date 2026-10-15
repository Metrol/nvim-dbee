-- Opt-in test: DBEE_POSTGRES_TEST_URL=... nvim --headless -i NONE '+luafile tests/postgres_parameters.lua'
local ok, err = xpcall(function()
  local url = assert(vim.env.DBEE_POSTGRES_TEST_URL, "Set DBEE_POSTGRES_TEST_URL")
  require("lazy").load { plugins = { "nvim-dbee" } }
  local dbee = require("dbee")
  local api = dbee.api.core
  local source = require("dbee.sources").MemorySource:new({
    { id = "binding-check", name = "Binding check", type = "postgres", url = url },
  }, "binding-check")
  api.add_source(source)
  local connection = api.source_get_connections(source:name())[1]
  api.set_current_connection(connection.id)
  vim.cmd("enew")
  vim.bo.filetype = "sql"
  local buffer = vim.api.nvim_get_current_buf()
  local query = [[SELECT :text::text AS text_value, :empty::text AS empty_value,
    :nothing::text IS NULL AS null_value, :big::numeric::text AS precise_value,
    :truth::boolean AS boolean_value, :text::text AS repeated_value;]]
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(query, "\n"))
  local values = {
    text = { text = "O'Reilly \\ Unicode 界\n'; SELECT 'not executed'; --", is_null = false },
    empty = { text = "", is_null = false },
    nothing = { text = "", is_null = true },
    big = { text = "900719925474099312345.6789", is_null = false },
    truth = { text = "true", is_null = false },
  }
  local parameters = require("dbee.parameters")
  local old_prompt = parameters.prompt
  local prompts = 0
  parameters.prompt = function(names, defaults, callback)
    prompts = prompts + 1
    assert(#names == 5, "Repeated names must prompt only once")
    if prompts > 1 then
      assert(defaults.text.text == values.text.text)
    end
    callback(vim.deepcopy(values))
  end
  local function run()
    local call
    api.connection_run(connection.id, query, buffer, function(result)
      call = result
    end)
    assert(call and call.query == query)
    local finished
    assert(
      vim.wait(5000, function()
        for _, candidate in ipairs(api.connection_get_calls(connection.id)) do
          if candidate.id == call.id and (candidate.state == "archived" or candidate.error) then
            finished = candidate
            return true
          end
        end
        return false
      end),
      "Bound query did not complete"
    )
    assert(not finished.error or finished.error == "", finished.error)
    local file = vim.fn.tempname()
    api.call_store_result(call.id, "json", "file", { extra_arg = file })
    local row = vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))[1]
    assert(row.text_value == values.text.text and row.repeated_value == values.text.text)
    assert(row.empty_value == "" and row.null_value == true)
    assert(row.precise_value == values.big.text and row.boolean_value == true)
  end
  run()
  run()
  assert(prompts == 2)
  assert(table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n") == query)
  local valid = pcall(api.connection_parameters, connection.id, "SELECT :id; SELECT 2;")
  assert(not valid, "Parameterized batches must be rejected before execution")
  assert(#api.connection_parameters(connection.id, "SELECT 1; SELECT 2;") == 0)
  parameters.prompt = old_prompt
  print(
    "PASS: real PostgreSQL binding, escaping, Unicode, NULL, empty text, precision, repeated names, session defaults"
  )
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
