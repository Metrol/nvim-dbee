local M = {}
local remembered = {}

vim.api.nvim_create_autocmd("BufWipeout", {
  callback = function(event)
    remembered[event.buf] = nil
  end,
})

---Prompt once for each distinct name, retaining explicit NULL independently.
function M.prompt(names, defaults, callback)
  local Input = require("nui.input")
  local values = {}
  local function next_value(index)
    local name = names[index]
    if not name then
      callback(values)
      return
    end
    local previous = defaults[name] or { text = "", is_null = false }
    local is_null = previous.is_null
    local initial = previous.text
    local input
    local function title()
      return string.format(
        " :%s (%d/%d)%s | Ctrl-N: NULL | Esc: cancel ",
        name,
        index,
        #names,
        is_null and " [NULL]" or ""
      )
    end
    input = Input({
      position = "50%",
      size = { width = math.max(20, math.min(85, vim.o.columns - 6)) },
      border = { style = "rounded", text = { top = title(), top_align = "center" } },
    }, {
      prompt = ":" .. name .. " = ",
      default_value = initial,
      on_change = function(value)
        if value ~= initial and is_null then
          is_null = false
          input.border:set_text("top", title(), "center")
        end
      end,
      on_submit = function(value)
        values[name] = { text = value, is_null = is_null }
        next_value(index + 1)
      end,
      on_close = function()
        callback(nil)
      end,
    })
    for _, mode in ipairs { "i", "n" } do
      input:map(mode, "<Esc>", function()
        input:unmount()
      end, { noremap = true })
      input:map(mode, "<C-n>", function()
        is_null = not is_null
        input.border:set_text("top", title(), "center")
      end, { noremap = true })
    end
    input:mount()
  end
  next_value(1)
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
