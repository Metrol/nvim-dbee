-- nvim --headless -u NONE -i NONE -l tests/result_headers.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.env.NUI_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nui.nvim")
local ok, err = xpcall(function()
  vim.o.lines, vim.o.columns = 35, 90
  if vim.fn.exists("+winborder") == 1 then
    vim.o.winborder = "rounded"
  end
  vim.go.scrolloff = 5
  local Result = require("dbee.ui.result")
  local calls = {}
  local rows = {
    "    │ name界   │ " .. string.rep("wide", 24) .. " │ 100% %name",
    "────┼──────────┼"
      .. string.rep("─", 98)
      .. "┼───────────",
  }
  for index = 1, 80 do
    rows[#rows + 1] = string.format("%3d │ value%d  │ %s │ last%d", index, index, string.rep("x", 96), index)
  end
  local handler = {
    register_event_listener = function() end,
    call_display_result = function(_, _, buffer, first)
      vim.bo[buffer].modifiable = true
      local page = vim.deepcopy(rows)
      if first > 0 then
        page[1] = page[1]:gsub("name界", "page界")
      end
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, page)
      vim.bo[buffer].modifiable = false
      return 160
    end,
    call_store_result = function(_, ...)
      calls[#calls + 1] = { ... }
    end,
  }
  local result = Result:new(handler, require("dbee.config").default.result)
  local win = vim.api.nvim_get_current_win()
  result:set_call { id = "first", time_taken_us = 100, state = "archived" }
  result:show(win)
  vim.wo[win].signcolumn = "yes"
  local header = result.header
  assert(header and not header.float, "Do not duplicate the original visible header")
  assert(vim.wo[win].scrolloff >= 5, "Inherited scrolloff must be preserved")
  local original = vim.api.nvim_buf_get_lines(result.bufnr, 0, -1, false)
  vim.api.nvim_win_set_cursor(win, { 30, 0 })
  vim.cmd("normal! zt")
  vim.cmd("redraw")
  header:update()
  assert(header.float and vim.api.nvim_win_is_valid(header.float), "Scrolled results need a pinned header")
  assert(vim.api.nvim_get_current_win() == win, "Header must not take focus")
  assert(not vim.api.nvim_win_get_config(header.float).focusable)
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(header.header_buf, 0, -1, false), { rows[1], rows[2] }))
  local function view(window)
    return vim.api.nvim_win_call(window, vim.fn.winsaveview)
  end
  result:move_column(1, 3)
  vim.cmd("redraw")
  header:update()
  assert(view(win).leftcol > 0)
  assert(view(win).leftcol == view(header.float).leftcol, "Header must follow column jumps")
  vim.cmd("normal! 10zh")
  header:update()
  assert(view(win).leftcol == view(header.float).leftcol, "Header must follow ordinary horizontal scrolling")
  vim.cmd('normal! vll"ay')
  assert(#vim.fn.getreg("a") > 0, "Text remains selectable")
  assert(
    vim.deep_equal(original, vim.api.nvim_buf_get_lines(result.bufnr, 0, -1, false)),
    "Pinning must not edit result text"
  )
  vim.cmd("normal! $")
  vim.cmd("redraw")
  header:update()
  assert(
    view(win).leftcol == view(header.float).leftcol,
    "Trailing columns must stay aligned beyond shorter header lines"
  )
  vim.cmd("redraw")
  local body_info = vim.fn.getwininfo(win)[1]
  local pinned_info = vim.fn.getwininfo(header.float)[1]
  assert(pinned_info.wincol == body_info.wincol + body_info.textoff, "Header must start after the gutter")
  assert(pinned_info.winrow == body_info.winrow + body_info.winbar, "Header must sit below the status bar")
  result:store_current_wrapper("json", "b")
  assert(calls[1][4].to == calls[1][4].from + 1, "Row export indexing must stay intact")
  vim.cmd("vsplit")
  vim.api.nvim_set_current_win(win)
  header:update()
  assert(
    vim.api.nvim_win_get_width(header.float) == vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
  )
  local other = vim.fn.win_getid(vim.fn.winnr("#"))
  vim.api.nvim_win_close(other, true)
  header:update()
  assert(
    vim.api.nvim_win_get_width(header.float) == vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
  )
  vim.cmd("normal! gg0")
  header:update()
  assert(not header.float, "Returning to the top must remove the overlay")
  result:page_next()
  vim.api.nvim_win_set_cursor(win, { 30, 0 })
  vim.cmd("normal! zt")
  header:update()
  assert(
    vim.api.nvim_buf_get_lines(header.header_buf, 0, 1, false)[1]:find("page界", 1, true),
    "Page changes must refresh headers"
  )
  result:set_call { id = "second", time_taken_us = 100, state = "executing_failed", error = "test" }
  assert(not header.float)
  result:display_status()
  header:update()
  assert(not header.float, "Failures must not retain a stale header")
  result:page_first()
  vim.api.nvim_win_set_cursor(win, { 30, 0 })
  vim.cmd("normal! zt")
  header:update()
  assert(header.float)
  local float = header.float
  vim.cmd("enew!")
  assert(not vim.api.nvim_win_is_valid(float), "Hiding results must close the overlay")
  local disabled = Result:new(handler, { pin_headers = false })
  assert(not disabled.header, "Feature must be optional")
  print("PASS: pinned headers, horizontal alignment, Unicode, resize, pagination, copying, errors, hide, and opt-out")
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
