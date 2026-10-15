-- nvim --headless -u NONE -i NONE -l tests/result_header_events.lua
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE" }, { rpc = true })
local function lua(code, ...)
  return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end
local function wait(code)
  assert(
    vim.wait(2000, function()
      return lua(code)
    end, 10),
    code
  )
end
local ok, err = xpcall(function()
  lua(
    [[
  local root,nui=...; vim.opt.rtp:prepend(root);vim.opt.rtp:append(nui)
  vim.o.lines=25;vim.o.columns=70
  _G.errors={};vim.notify=function(msg,level) if level==vim.log.levels.ERROR then errors[#errors+1]=msg end end
  _G.win=vim.api.nvim_get_current_win()
  _G.result=require('dbee.ui.result'):new({register_event_listener=function() end},require('dbee.config').default.result)
  result:show(win)
  local rows={'    │ first │ '..string.rep('head',30)..' │ final','────┼───────┼'..string.rep('─',122)..'┼──────'}
  for i=1,100 do rows[#rows+1]=string.format('%3d │ data  │ %s │ end',i,string.rep('x',120)) end
  vim.bo[result.bufnr].modifiable=true;vim.api.nvim_buf_set_lines(result.bufnr,0,-1,false,rows);vim.bo[result.bufnr].modifiable=false
  result.header:refresh()
 ]],
    vim.fn.getcwd(),
    vim.env.NUI_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nui.nvim"
  )
  lua("vim.cmd('normal! 40Gzt')")
  wait("return result.header.float ~= nil")
  lua("result:move_column(1,3)")
  wait(
    "return vim.api.nvim_win_call(win,vim.fn.winsaveview).leftcol > 0 and vim.api.nvim_win_call(win,vim.fn.winsaveview).leftcol == vim.api.nvim_win_call(result.header.float,vim.fn.winsaveview).leftcol"
  )
  lua("vim.cmd('normal! gg0')")
  wait("return result.header.float == nil")
  lua("vim.cmd('normal! 40Gzt')")
  wait("return result.header.float ~= nil")
  lua('vim.cmd("tabnew")')
  wait("return result.header.float == nil")
  lua('vim.cmd("tabprevious")')
  wait("return result.header.float ~= nil")
  lua("vim.o.columns=100")
  wait("return vim.api.nvim_win_get_width(result.header.float) == vim.api.nvim_win_get_width(win)")
  lua('vim.cmd("vsplit"); vim.api.nvim_win_close(win,true)')
  wait("return result.header.float == nil")
  assert(lua("return #errors") == 0)
  print("PASS: automatic scroll, horizontal sync, tabs, resize, and window-close cleanup")
end, debug.traceback)
pcall(vim.rpcnotify, child, "nvim_command", "qa!")
vim.fn.jobwait({ child }, 1000)
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
