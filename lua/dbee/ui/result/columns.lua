local M = {}

---Read display-column starts from the separator, not data containing pipes.
---@param lines string[]
---@return integer[] one-based display positions, excluding row numbers
function M.starts(lines)
  for _, line in ipairs(lines) do
    if line:find("┼", 1, true) and line:gsub("─", ""):gsub("┼", "") == "" then
      local starts, offset = {}, 1
      while true do
        local divider = line:find("┼", offset, true)
        if not divider then
          return starts
        end
        -- One cell for the separator and one for padding before the value.
        starts[#starts + 1] = vim.fn.strdisplaywidth(line:sub(1, divider - 1)) + 3
        offset = divider + #"┼"
      end
    end
  end
  return {}
end

---@param winid integer
---@param starts integer[]
---@param direction integer -1 for left, 1 for right
---@param count? integer
function M.move(winid, starts, direction, count)
  if #starts == 0 or not vim.api.nvim_win_is_valid(winid) then
    return
  end
  vim.api.nvim_win_call(winid, function()
    local cursor = vim.api.nvim_win_get_cursor(winid)
    local position = vim.fn.virtcol(".")
    local index = 0
    for i, start in ipairs(starts) do
      -- Include the preceding separator so an empty final cell is still a cell.
      if position >= start - 2 then
        index = i
      end
    end
    local target = math.max(1, math.min(#starts, index + direction * (count or 1)))
    local line = vim.api.nvim_get_current_line()
    local column = math.min(starts[target], math.max(1, vim.fn.strdisplaywidth(line)))
    local byte = vim.fn.virtcol2col(winid, cursor[1], column)
    vim.api.nvim_win_set_cursor(winid, { cursor[1], math.max(0, byte - 1) })
  end)
end

return M
