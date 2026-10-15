-- Run from the repository root:
-- nvim --headless -u NONE -i NONE -l tests/result_columns.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.env.NUI_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nui.nvim")

local ok, err = xpcall(function()
  local Result = require("dbee.ui.result")
  local defaults = require("dbee.config").default.result
  local result = Result:new({ register_event_listener = function() end }, defaults)
  local win = vim.api.nvim_get_current_win()
  result:show(win)
  local buffer = vim.api.nvim_get_current_buf()
  local function render(lines)
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.bo[buffer].modifiable = false
  end
  local function at(row, display)
    local byte = vim.fn.virtcol2col(win, row, display)
    vim.api.nvim_win_set_cursor(win, { row, math.max(0, byte - 1) })
  end
  render {
    "   │ first        │ second │ third",
    "───┼──────────────┼────────┼───────",
    " 1 │ left │ value │ 界🙂   │    42",
  }
  at(3, 6)
  result:do_action("column_next")
  assert(vim.fn.virtcol(".", true)[1] == 21, "Embedded pipes must not create columns")
  assert(vim.api.nvim_win_get_cursor(win)[1] == 3, "Column jumps must preserve the row")
  result:do_action("column_next")
  assert(vim.fn.virtcol(".", true)[1] == 30, "Unicode must not shift column positions")
  result:do_action("column_next")
  assert(vim.fn.virtcol(".", true)[1] == 30, "Right edge must not wrap")
  result:move_column(-1, 9)
  assert(vim.fn.virtcol(".", true)[1] == 6, "Left edge must clamp")
  result:do_action("column_prev")
  assert(vim.fn.virtcol(".", true)[1] == 6)
  result:move_column(1, 2)
  assert(vim.fn.virtcol(".", true)[1] == 30, "Counts must jump multiple columns")
  at(3, 6)
  vim.cmd.normal { args = { vim.api.nvim_replace_termcodes("2<Right>", true, false, true) }, bang = false }
  assert(vim.fn.virtcol(".", true)[1] == 30, "Counted arrow mappings must invoke column jumps")
  at(3, 6)
  vim.cmd.normal { args = { vim.api.nvim_replace_termcodes("v<Right><Right>y", true, false, true) }, bang = false }
  assert(vim.fn.getreg('"') == "lef", "Visual arrows must still select individual characters for copying")
  at(1, 6)
  result:do_action("column_next")
  assert(vim.api.nvim_win_get_cursor(win)[1] == 1, "Header navigation must preserve row")

  render { "   │ first │ empty", "───┼───────┼──────", " 1 │ value │" }
  at(3, 6)
  result:do_action("column_next")
  result:do_action("column_prev")
  assert(vim.fn.virtcol(".", true)[1] == 6, "Empty trailing cells must navigate back correctly")
  render { "   │ only", "───┼─────", " 1 │ x" }
  at(3, 6)
  result:do_action("column_next")
  assert(vim.fn.virtcol(".", true)[1] == 6, "Single-column results must stay in place")
  render { "Call execution failed" }
  at(1, 1)
  result:do_action("column_next")
  assert(vim.api.nvim_win_get_cursor(win)[2] == 0, "Errors must not use stale column positions")

  local padding = string.rep("─", 120)
  render {
    "   │ first",
    "───┼" .. padding .. "┼──────",
    " 1 │ " .. string.rep("x", 118) .. " │ end",
  }
  at(3, 6)
  result:do_action("column_next")
  vim.cmd("redraw")
  assert(vim.fn.winsaveview().leftcol > 0, "Offscreen columns must scroll into view")
  assert(vim.fn.maparg("<Right>", "n", false, true).buffer == 1)
  assert(vim.fn.maparg("<Left>", "n", false, true).buffer == 1)
  assert(vim.fn.maparg("<Right>", "x") == "", "Visual arrows must remain ordinary text motions")
  assert(vim.fn.maparg("h", "n") == "" and vim.fn.maparg("l", "n") == "")
  print("PASS: result-column jumps, counts, edges, Unicode, empty cells, scrolling, copy motions")
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
