local M = {}
local remembered = {}

vim.api.nvim_create_autocmd("BufWipeout", {
  callback = function(event)
    remembered[event.buf] = nil
  end,
})

---Show all distinct parameters in one editable form.
function M.prompt(names, defaults, callback)
  if #names == 0 then
    callback {}
    return
  end
  local Popup = require("nui.popup")
  local values, lines = {}, {}
  for index, name in ipairs(names) do
    values[name] = vim.deepcopy(defaults[name] or { text = "", is_null = false })
    -- Existing multiline values remain exact until this field is edited.
    lines[index] = values[name].text:gsub("\n", "↵"):gsub("\r", "␍")
  end
  local origin = vim.api.nvim_get_current_win()
  local popup = Popup {
    relative = "editor",
    position = "50%",
    size = {
      width = math.max(20, math.min(100, vim.o.columns - 6)),
      height = math.min(#names, math.max(1, vim.o.lines - 8)),
    },
    enter = true,
    border = {
      style = "rounded",
      text = {
        top = " Parameters | Ctrl-Enter/Ctrl-S: Run | Esc: cancel ",
        top_align = "center",
        bottom = " Tab/Enter: next | Shift-Tab: back | Ctrl-N: NULL ",
      },
    },
    buf_options = { buftype = "nofile", swapfile = false, filetype = "dbee-parameters" },
    win_options = { wrap = false, number = false, relativenumber = false, cursorline = true, signcolumn = "no" },
  }
  local namespace = vim.api.nvim_create_namespace("dbee-parameter-form")
  local closed, restoring = false, false
  local function render()
    vim.api.nvim_buf_clear_namespace(popup.bufnr, namespace, 0, -1)
    for index, name in ipairs(names) do
      vim.api.nvim_buf_set_extmark(popup.bufnr, namespace, index - 1, 0, {
        virt_text = { { ":" .. name .. (values[name].is_null and " [NULL]" or "") .. " = ", "Title" } },
        virt_text_pos = "inline",
        right_gravity = false,
      })
    end
  end
  local function sync()
    local current = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    if #current ~= #names then
      return false
    end
    for index, name in ipairs(names) do
      if current[index] ~= lines[index] then
        values[name] = { text = current[index], is_null = false }
      end
    end
    lines = current
    render()
    return true
  end
  local function finish(submit)
    if closed then
      return
    end
    if submit and not sync() then
      vim.notify(
        "Use one line per parameter; multiline pastes cannot add fields.",
        vim.log.levels.WARN,
        { title = "DBee parameters" }
      )
      return
    end
    closed = true
    vim.cmd("stopinsert")
    popup:unmount()
    if vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_set_current_win(origin)
    end
    vim.schedule(function()
      callback(submit and values or nil)
    end)
  end
  local function focus(index)
    if closed or not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
      return
    end
    index = (index - 1) % #names + 1
    vim.api.nvim_set_current_win(popup.winid)
    vim.api.nvim_win_set_cursor(popup.winid, { index, #lines[index] })
    -- Start after focus and any prior mode transition have completed.
    vim.schedule(function()
      if not closed and vim.api.nvim_get_current_win() == popup.winid then
        vim.cmd("startinsert!")
      end
    end)
  end
  local function move(delta)
    if sync() then
      focus(vim.api.nvim_win_get_cursor(popup.winid)[1] + delta)
    end
  end
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  render()
  vim.api.nvim_buf_attach(popup.bufnr, false, {
    on_lines = function()
      if closed or restoring then
        return
      end
      if not sync() then
        restoring = true
        vim.schedule(function()
          if not closed and vim.api.nvim_buf_is_valid(popup.bufnr) then
            vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
            render()
            vim.notify(
              "Use one line per parameter; multiline paste was cancelled.",
              vim.log.levels.WARN,
              { title = "DBee parameters" }
            )
          end
          restoring = false
        end)
      end
    end,
  })
  for _, mode in ipairs { "i", "n" } do
    popup:map(mode, "<Tab>", function()
      move(1)
    end, { noremap = true })
    popup:map(mode, "<S-Tab>", function()
      move(-1)
    end, { noremap = true })
    popup:map(mode, "<CR>", function()
      move(1)
    end, { noremap = true })
    popup:map(mode, "<C-n>", function()
      if not sync() then
        return
      end
      local name = names[vim.api.nvim_win_get_cursor(popup.winid)[1]]
      values[name].is_null = not values[name].is_null
      render()
    end, { noremap = true })
    popup:map(mode, "<C-s>", function()
      finish(true)
    end, { noremap = true })
    popup:map(mode, "<C-CR>", function()
      finish(true)
    end, { noremap = true })
    popup:map(mode, "<Esc>", function()
      finish(false)
    end, { noremap = true })
    popup:map(mode, "<C-c>", function()
      finish(false)
    end, { noremap = true })
  end
  -- Backspace/Delete must not join neighboring fields.
  popup:map("i", "<BS>", function()
    return vim.fn.col(".") > 1 and vim.api.nvim_replace_termcodes("<BS>", true, false, true) or ""
  end, { expr = true, noremap = true })
  popup:map("i", "<Del>", function()
    return vim.fn.col(".") <= #vim.api.nvim_get_current_line()
        and vim.api.nvim_replace_termcodes("<Del>", true, false, true)
      or ""
  end, { expr = true, noremap = true })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = popup.bufnr,
    once = true,
    callback = function()
      if not closed then
        closed = true
        vim.schedule(function()
          vim.cmd("stopinsert")
          popup:unmount()
          callback(nil)
        end)
      end
    end,
  })
  popup:mount()
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(popup.winid),
    once = true,
    callback = function()
      vim.schedule(function()
        finish(false)
      end)
    end,
  })
  focus(1)
end

---Run unparameterized SQL unchanged; bind named values through the Go backend.
function M.run(handler, connection_id, query, bufnr, callback)
  local ok, names = pcall(handler.connection_parameters, handler, connection_id, query)
  if not ok then
    vim.notify(tostring(names), vim.log.levels.ERROR, { title = "DBee parameters" })
    return
  end
  local function execute(values)
    local success, call
    if values then
      success, call = pcall(handler.connection_execute_bound, handler, connection_id, query, values)
    else
      success, call = pcall(handler.connection_execute, handler, connection_id, query)
    end
    if success then
      callback(call)
    else
      vim.notify(tostring(call), vim.log.levels.ERROR, { title = "DBee query" })
    end
  end
  if #names == 0 then
    execute(nil)
    return
  end
  remembered[bufnr] = remembered[bufnr] or {}
  local defaults = remembered[bufnr][connection_id] or {}
  M.prompt(names, vim.deepcopy(defaults), function(values)
    if not values or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    remembered[bufnr][connection_id] = vim.tbl_extend("force", defaults, vim.deepcopy(values))
    execute(values)
  end)
end

return M
