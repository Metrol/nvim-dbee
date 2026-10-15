-- nvim --headless -u NONE -i NONE -l tests/parameter_prompt.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nui.nvim")
local ok, err = xpcall(function()
  local Input = require("nui.input")
  local active
  package.loaded["nui.input"] = function(options, props)
    active = Input(options, props)
    return active
  end
  local parameters = require("dbee.parameters")
  local result
  parameters.prompt({ "text", "empty", "nothing" }, {
    text = { text = "O'Reilly", is_null = false },
  }, function(values)
    result = values
  end)
  assert(vim.api.nvim_buf_get_lines(active.bufnr, 0, 1, false)[1] == ":text = O'Reilly")
  vim.wait(20, function()
    return false
  end)
  active.input_props.on_submit("O'Reilly")
  assert(vim.wait(1000, function()
    return active._.prompt:content() == ":empty = "
  end))
  vim.wait(20, function()
    return false
  end)
  active.input_props.on_submit("")
  assert(vim.wait(1000, function()
    return active._.prompt:content() == ":nothing = "
  end))
  local toggle = vim.api.nvim_buf_call(active.bufnr, function()
    return vim.fn.maparg("<C-n>", "i", false, true).callback
  end)
  assert(type(toggle) == "function")
  toggle()
  vim.wait(20, function()
    return false
  end)
  active.input_props.on_submit("")
  assert(vim.wait(1000, function()
    return result ~= nil
  end))
  assert(result.text.text == "O'Reilly" and not result.text.is_null)
  assert(result.empty.text == "" and not result.empty.is_null)
  assert(result.nothing.is_null)
  local cancelled = false
  parameters.prompt({ "nothing" }, result, function(values)
    cancelled = values == nil
  end)
  local escape = vim.api.nvim_buf_call(active.bufnr, function()
    return vim.fn.maparg("<Esc>", "i", false, true).callback
  end)
  vim.wait(20, function()
    return false
  end)
  escape()
  assert(vim.wait(1000, function()
    return cancelled
  end))
  print("PASS: real Nui prompts, defaults, empty text, NULL toggle, and cancellation")
end, debug.traceback)
vim.cmd("stopinsert")
if not ok then
  print(err)
end
vim.cmd(ok and "qa!" or "cquit")
