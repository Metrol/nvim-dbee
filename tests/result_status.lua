-- nvim --headless -u NONE -i NONE -l tests/result_status.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.env.NUI_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nui.nvim")
local ok, err = xpcall(function()
  local status = require("dbee.ui.result.status")
  local win = vim.api.nvim_get_current_win()
  local summary =
    { count = "1/2 (150)", timing = "Took 0.024s", query = '\n SELECT *\n FROM "RFP"\t WHERE "eventID" = :eventID;\n' }
  local function render(width)
    return vim.api.nvim_eval_statusline(
      status.format(summary, width),
      { winid = win, use_winbar = true, maxwidth = width, fillchar = " " }
    ).str
  end
  local shown = render(100)
  assert(shown:find('SELECT * FROM "RFP" WHERE "eventID" = :eventID;', 1, true))
  assert(shown:find(summary.count, 1, true) and shown:find(summary.timing, 1, true))
  summary.query = 'SELECT "界🙂字段", "é" FROM "RFP" WHERE ' .. string.rep("long ", 30)
  for _, width in ipairs { 25, 35, 50, 100 } do
    shown = render(width)
    assert(vim.fn.strdisplaywidth(shown) <= width)
    assert(shown:find(summary.count, 1, true) and shown:find(summary.timing, 1, true))
    assert(shown:find("…", 1, true), "Long SQL needs a truncation indicator")
    assert(not shown:find("�", 1, true), "Truncation must preserve UTF-8")
  end
  vim.g.dbee_status_executed = 0
  summary.query = [[SELECT '%{execute("let g:dbee_status_executed=1")}', '100%' AS literal]]
  shown = render(150)
  assert(vim.g.dbee_status_executed == 0, "SQL must never run as a winbar expression")
  assert(shown:find(summary.query, 1, true), "Percent signs must display literally")
  shown = render(22)
  assert(
    not shown:find("SELECT", 1, true) and shown:find(summary.count, 1, true) and shown:find(summary.timing, 1, true)
  )
  summary.query = nil
  assert(not render(100):find("nil", 1, true))

  local Result = require("dbee.ui.result")
  local result = Result:new({
    register_event_listener = function() end,
    call_display_result = function(_, _, buffer)
      vim.bo[buffer].modifiable = true
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "  │ id", "──┼───", "1 │ 42" })
      vim.bo[buffer].modifiable = false
      return 150
    end,
  }, require("dbee.config").default.result)
  result:set_call { id = "first", query = 'SELECT * FROM "RFP";', time_taken_us = 24000 }
  result:show(win)
  assert(vim.wo[win].winbar:find('SELECT * FROM "RFP";', 1, true))
  result:page_next()
  assert(vim.wo[win].winbar:find("2/2 (150)", 1, true))
  assert(vim.wo[win].winbar:find('SELECT * FROM "RFP";', 1, true))
  vim.cmd("vsplit")
  vim.api.nvim_win_set_width(win, 30)
  result:update_winbar()
  assert(vim.wo[win].winbar:find("…", 1, true))
  vim.api.nvim_win_set_width(win, 70)
  result:update_winbar()
  assert(vim.wo[win].winbar:find('SELECT * FROM "RFP";', 1, true))
  result:set_call { id = "second", query = 'SELECT 2 AS "other";', time_taken_us = 100 }
  assert(not vim.wo[win].winbar:find("RFP", 1, true), "New calls must clear the old label immediately")
  result:page_current()
  assert(vim.wo[win].winbar:find('SELECT 2 AS "other";', 1, true))
  print(
    "PASS: executed-query previews, page changes, width limits, Unicode, literal percent signs, and query switching"
  )
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
