local Header = {}
Header.__index = Header

---Keep a copy of the rendered header above vertically scrolled result rows.
function Header.new(bufnr)
  local self = setmetatable({ bufnr = bufnr, ready = false }, Header)
  self.group = vim.api.nvim_create_augroup("dbee-pinned-header-" .. bufnr, { clear = true })
  local pending = false
  local function schedule()
    if pending then
      return
    end
    pending = true
    vim.schedule(function()
      pending = false
      self:update()
    end)
  end
  vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "VimResized", "CursorMoved", "BufWinEnter", "TabEnter" }, {
    group = self.group,
    callback = schedule,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self.group,
    callback = function(event)
      if tonumber(event.match) == self.winid then
        self:clear()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufHidden", "BufUnload", "BufWipeout" }, {
    group = self.group,
    buffer = bufnr,
    callback = function(event)
      self:clear()
      if event.event == "BufWipeout" then
        vim.api.nvim_del_augroup_by_id(self.group)
      end
    end,
  })
  vim.api.nvim_create_autocmd("TabLeave", {
    group = self.group,
    callback = function()
      self:hide()
    end,
  })
  return self
end

function Header:hide()
  if self.float and vim.api.nvim_win_is_valid(self.float) then
    vim.api.nvim_win_close(self.float, true)
  end
  self.float, self.geometry = nil, nil
  if self.header_buf and vim.api.nvim_buf_is_valid(self.header_buf) then
    vim.api.nvim_buf_delete(self.header_buf, { force = true })
  end
  self.header_buf = nil
end

function Header:clear()
  self.ready = false
  self:hide()
  if self.saved_scrolloff ~= nil and self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.wo[self.winid].scrolloff = self.saved_scrolloff
  end
  self.saved_scrolloff = nil
  self.tick, self.lines = nil, nil
end

function Header:set_window(winid)
  if self.winid ~= winid then
    self:clear()
  end
  self.winid = winid
end

function Header:refresh()
  self.ready, self.tick = true, nil
  self:update()
end

function Header:update()
  if self.updating then
    return
  end
  if
    not self.ready
    or not self.winid
    or not vim.api.nvim_win_is_valid(self.winid)
    or not vim.api.nvim_buf_is_valid(self.bufnr)
    or vim.api.nvim_win_get_buf(self.winid) ~= self.bufnr
    or vim.api.nvim_win_get_tabpage(self.winid) ~= vim.api.nvim_get_current_tabpage()
  then
    self:hide()
    return
  end
  local tick = vim.api.nvim_buf_get_changedtick(self.bufnr)
  if self.tick ~= tick then
    self.tick, self.lines = tick, nil
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    for index, line in ipairs(lines) do
      if line:find("┼", 1, true) and line:gsub("─", ""):gsub("┼", "") == "" then
        if index > 1 then
          self.lines = vim.list_slice(lines, 1, index)
        end
        break
      end
    end
    if self.header_buf and vim.api.nvim_buf_is_valid(self.header_buf) and self.lines then
      vim.bo[self.header_buf].modifiable = true
      vim.api.nvim_buf_set_lines(self.header_buf, 0, -1, false, self.lines)
      vim.bo[self.header_buf].modifiable = false
    end
  end
  if not self.lines then
    self:clear()
    return
  end
  local height = #self.lines
  if height >= vim.api.nvim_win_get_height(self.winid) then
    self:hide()
    return
  end
  -- Leave enough space above the cursor so the overlay cannot obscure it.
  if self.saved_scrolloff == nil then
    self.saved_scrolloff = vim.wo[self.winid].scrolloff
  end
  local scrolloff = self.saved_scrolloff < 0 and vim.go.scrolloff or self.saved_scrolloff
  vim.wo[self.winid].scrolloff = math.max(scrolloff, height)
  local view = vim.api.nvim_win_call(self.winid, vim.fn.winsaveview)
  if view.topline == 1 then
    self:hide()
    return
  end
  local offset = vim.fn.getwininfo(self.winid)[1].textoff
  local geometry = {
    relative = "win",
    win = self.winid,
    row = 0,
    col = offset,
    width = math.max(1, vim.api.nvim_win_get_width(self.winid) - offset),
    height = height,
    focusable = false,
    style = "minimal",
    border = "none",
    zindex = 40,
    noautocmd = true,
  }
  self.updating = true
  if not self.float or not vim.api.nvim_win_is_valid(self.float) then
    self.header_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[self.header_buf].bufhidden = "wipe"
    vim.bo[self.header_buf].swapfile = false
    vim.api.nvim_buf_set_lines(self.header_buf, 0, -1, false, self.lines)
    vim.bo[self.header_buf].modifiable = false
    self.float = vim.api.nvim_open_win(self.header_buf, false, geometry)
    vim.wo[self.float].wrap = false
    vim.wo[self.float].scrolloff = 0
    vim.wo[self.float].sidescrolloff = 0
    vim.wo[self.float].winhighlight = "Normal:Normal,NormalFloat:Normal"
    vim.api.nvim_win_call(self.float, function()
      vim.cmd([[match NonText /─\|│\|┼/]])
    end)
    self.geometry = geometry
  elseif not vim.deep_equal(self.geometry, geometry) then
    vim.api.nvim_win_set_config(self.float, geometry)
    self.geometry = geometry
  end
  local header_view = vim.api.nvim_win_call(self.float, vim.fn.winsaveview)
  if header_view.leftcol ~= view.leftcol then
    vim.api.nvim_win_call(self.float, function()
      local byte = vim.fn.virtcol2col(self.float, height, view.leftcol + 1)
      vim.fn.winrestview { topline = 1, leftcol = view.leftcol, lnum = height, col = math.max(0, byte - 1) }
    end)
  end
  self.updating = false
end

return Header
