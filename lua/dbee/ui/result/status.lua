local M = {}

---Truncate by display cells without splitting UTF-8 characters.
local function shorten(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  local low, high = 0, vim.fn.strchars(text)
  while low < high do
    local middle = math.ceil((low + high) / 2)
    if vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, middle)) <= width - 1 then
      low = middle
    else
      high = middle - 1
    end
  end
  return vim.fn.strcharpart(text, 0, low) .. "…"
end

---Keep the count and timing intact, fitting a literal SQL preview between them.
function M.format(status, width)
  local query = (status.query or ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
  local available = width - vim.fn.strdisplaywidth(status.count) - vim.fn.strdisplaywidth(status.timing) - 3
  local left = status.count
  if available > 0 and query ~= "" then
    -- SQL is literal status text: percent signs must not become winbar expressions.
    left = left .. "  " .. shorten(query, available):gsub("%%", "%%%%")
  end
  return left .. "%=" .. status.timing
end

return M
