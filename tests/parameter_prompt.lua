-- nvim --headless -u NONE -i NONE -l tests/parameter_prompt.lua
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE" }, { rpc = true })
local function lua(code, ...)
  return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end
local function wait_for(code)
  assert(
    vim.wait(2000, function()
      return lua(code)
    end, 10),
    code
  )
end
local function keys(input)
  vim.rpcrequest(child, "nvim_input", input)
end
local ok, err = xpcall(function()
  lua(
    [[
    local root, nui = ...
    vim.opt.rtp:prepend(root)
    vim.opt.rtp:append(nui)
    vim.o.lines = 30
    vim.o.columns = 100
    local Popup = require("nui.popup")
    package.loaded["nui.popup"] = function(options)
      _G.form = Popup(options)
      return _G.form
    end
    _G.parameters = require("dbee.parameters")
    _G.result = false
    parameters.prompt({ "text", "empty", "nothing" }, {
      text = { text = "O'Reilly", is_null = false },
    }, function(values) _G.result = values or "cancelled" end)
  ]],
    vim.fn.getcwd(),
    vim.env.NUI_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nui.nvim"
  )
  wait_for('return vim.fn.mode() == "i"')
  assert(lua("return vim.api.nvim_buf_line_count(form.bufnr)") == 3, "All fields must be shown together")
  assert(lua("return vim.api.nvim_buf_get_lines(form.bufnr, 0, 1, false)[1]") == "O'Reilly")
  assert(
    lua(
      'return #vim.api.nvim_buf_get_extmarks(form.bufnr, vim.api.nvim_create_namespace("dbee-parameter-form"), 0, -1, {})'
    ) == 3
  )
  keys("<Tab>")
  wait_for('return vim.fn.mode() == "i" and vim.api.nvim_win_get_cursor(form.winid)[1] == 2')
  keys("<Tab>")
  wait_for('return vim.fn.mode() == "i" and vim.api.nvim_win_get_cursor(form.winid)[1] == 3')
  keys("<C-n>")
  wait_for([[
    local marks = vim.api.nvim_buf_get_extmarks(form.bufnr, vim.api.nvim_create_namespace("dbee-parameter-form"), 0, -1, {details=true})
    return marks[3][4].virt_text[1][1]:find("[NULL]", 1, true) ~= nil
  ]])
  keys("<S-Tab>")
  wait_for('return vim.fn.mode() == "i" and vim.api.nvim_win_get_cursor(form.winid)[1] == 2')
  keys("<S-Tab>")
  wait_for('return vim.fn.mode() == "i" and vim.api.nvim_win_get_cursor(form.winid)[1] == 1')
  keys("<S-Tab>")
  wait_for('return vim.fn.mode() == "i" and vim.api.nvim_win_get_cursor(form.winid)[1] == 3')
  keys("<C-s>")
  wait_for('return type(result) == "table"')
  local values = lua("return result")
  assert(values.text.text == "O'Reilly" and not values.text.is_null)
  assert(values.empty.text == "" and not values.empty.is_null)
  assert(values.nothing.is_null)
  lua('parameters.prompt({ "nothing", "text" }, result, function(values) _G.result = values or "cancelled" end)')
  wait_for('return vim.fn.mode() == "i"')
  keys("literal")
  wait_for('return vim.api.nvim_buf_get_lines(form.bufnr, 0, 1, false)[1] == "literal"')
  keys("<C-CR>")
  wait_for("return not vim.api.nvim_buf_is_valid(form.bufnr or -1)")
  values = lua("return result")
  assert(values.nothing.text == "literal" and not values.nothing.is_null, "Editing NULL must restore a text value")
  lua('parameters.prompt({ "empty" }, {}, function(values) _G.result = values or "cancelled" end)')
  wait_for('return vim.fn.mode() == "i"')
  keys("<BS><Del>unchanged<Esc>")
  wait_for('return result == "cancelled"')
  lua([[
    local names = {}
    for index = 1, 10 do names[index] = "parameter" .. index end
    parameters.prompt(names, {}, function(values) _G.result = values or "cancelled" end)
  ]])
  wait_for('return vim.fn.mode() == "i"')
  assert(lua("return vim.api.nvim_win_get_height(form.winid)") == 10)
  for index = 2, 10 do
    keys("value<Tab>")
    wait_for('return vim.fn.mode() == "i" and vim.api.nvim_win_get_cursor(form.winid)[1] == ' .. index)
  end
  keys("last<C-s>")
  wait_for('return type(result) == "table" and result.parameter10 ~= nil')
  values = lua("return result")
  assert(values.parameter1.text == "value" and values.parameter10.text == "last")
  lua('parameters.prompt({ "first", "second" }, {}, function(values) _G.result = values or "cancelled" end)')
  wait_for('return vim.fn.mode() == "i"')
  keys("<BS><Del>")
  assert(lua("return vim.api.nvim_buf_line_count(form.bufnr)") == 2)
  lua([[
    vim.notify = function() end
    vim.api.nvim_buf_set_lines(form.bufnr, 0, 1, false, { "paste", "extra" })
  ]])
  wait_for("return vim.api.nvim_buf_line_count(form.bufnr) == 2")
  assert(lua("return vim.api.nvim_buf_get_lines(form.bufnr, 0, 1, false)[1]") == "")
  lua("vim.api.nvim_win_close(form.winid, true)")
  wait_for('return result == "cancelled"')
  lua('parameters.prompt({ "first" }, {}, function(values) _G.result = values or "wiped" end)')
  wait_for('return vim.fn.mode() == "i"')
  lua("vim.api.nvim_buf_delete(form.bufnr, { force = true })")
  wait_for('return result == "wiped"')
  print(
    "PASS: all fields visible, real Insert mode after every move, forward/back/wrap, NULL, defaults, Run keys, and cancellation"
  )
end, debug.traceback)
if child > 0 then
  pcall(vim.rpcnotify, child, "nvim_command", "qa!")
  vim.fn.jobwait({ child }, 1000)
end
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
