-- Run from the repository root:
-- nvim --headless -u NONE -i NONE -l tests/editor_buffers.lua
-- Set NUI_NVIM_PATH if nui.nvim is not installed under lazy.nvim's data path.
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(vim.env.NUI_NVIM_PATH or vim.fn.stdpath("data") .. "/lazy/nui.nvim")
vim.o.hidden = true

local ok, err = xpcall(function()
  local Editor = require("dbee.ui.editor")
  local current, calls = "first", {}
  local handler = {
    connection_parameters = function()
      return {}
    end,
    get_current_connection = function()
      return { id = current }
    end,
    set_current_connection = function(_, id)
      current = id
    end,
    connection_execute = function(_, id, query)
      calls[#calls + 1] = { id = id, query = query }
      return calls[#calls]
    end,
  }
  local result = { set_call = function() end }
  local directory = vim.fn.tempname() .. " project"
  vim.fn.mkdir(directory, "p")
  local file = directory .. "/query file.sql"
  vim.fn.writefile({ "SELECT 1;" }, file)
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.bo.filetype = "sql"
  local buffer = vim.api.nvim_get_current_buf()
  local original_enter = function() end
  vim.keymap.set("n", "<CR>", original_enter, { buffer = buffer })
  local listed, swap = vim.bo.buflisted, vim.bo.swapfile
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "SELECT 2;" })
  local editor = Editor:new(handler, result, {
    directory = directory .. "/notes",
    mappings = {
      { key = "BB", mode = "n", action = "run_file" },
      { key = "BB", mode = "v", action = "run_selection" },
      { key = "<CR>", mode = "n", action = "run_file" },
    },
  })
  local id = editor:attach_buffer(buffer, "first")
  editor:show(vim.api.nvim_get_current_win())
  assert(vim.api.nvim_get_current_buf() == buffer)
  assert(vim.api.nvim_buf_get_name(buffer) == file and vim.bo.modified)
  assert(vim.bo.buflisted == listed and vim.bo.swapfile == swap)
  assert(editor:attach_buffer(buffer, "first") == id)
  assert(#editor:namespace_get_notes("first") == 1)
  current = "second"
  editor:do_action("run_file")
  assert(calls[1].id == "first" and calls[1].query == "SELECT 2;")
  vim.cmd.write()
  assert(vim.fn.readfile(file)[1] == "SELECT 2;")
  assert(not pcall(editor.note_rename, editor, id, "renamed.sql"))

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "SELECT 2;", "SELECT 3;" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("normal! V")
  editor:do_action("run_selection")
  assert(calls[2].query == "SELECT 3;", "Linewise BB selection must not execute the whole file")

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("normal! Vj")
  editor:do_action("run_selection")
  assert(calls[3].query == "SELECT 2;\nSELECT 3;", "Multiline selection must preserve newlines")

  -- Rebinding moves the existing entry instead of duplicating it.
  assert(editor:attach_buffer(buffer, "second") == id)
  assert(#editor:namespace_get_notes("first") == 0)
  editor:set_current_note(id)
  assert(current == "second")
  local renamed = directory .. "/saved query.sql"
  vim.api.nvim_buf_set_name(buffer, renamed)
  assert(editor:search_note(id).file == renamed)
  editor:namespace_remove_note("second", id)
  assert(vim.fn.filereadable(file) == 1 and vim.api.nvim_buf_is_valid(buffer))
  assert(vim.api.nvim_buf_call(buffer, function()
    return vim.fn.maparg("<CR>", "n", false, true).callback
  end) == original_enter)

  -- Attachment is session-only; a new editor never reloads project entries.
  local global_note = editor:namespace_get_notes("global")[1]
  vim.fn.writefile({ "-- Existing scratchpad" }, global_note.file)
  local fresh = Editor:new(handler, result, { directory = directory .. "/notes" })
  assert(#fresh:namespace_get_notes("second") == 0)
  editor:attach_buffer(buffer, "first")
  vim.api.nvim_buf_delete(buffer, { force = true })
  assert(vim.wait(1000, function()
    return editor:search_note(id) == nil
  end))
  assert(vim.fn.filereadable(file) == 1)
  -- Unnamed queries can be attached first and saved to a project later.
  vim.cmd("enew")
  vim.bo.filetype = "sql"
  local unnamed = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(unnamed, 0, -1, false, { "SELECT 4;" })
  local unnamed_id = editor:attach_buffer(unnamed, "first")
  assert(editor:search_note(unnamed_id).file == "")
  local saved = directory .. "/new query.sql"
  vim.cmd.saveas(vim.fn.fnameescape(saved))
  assert(editor:search_note(unnamed_id).file == saved)
  assert(vim.api.nvim_get_current_buf() == unnamed)
  assert(vim.fn.readfile(saved)[1] == "SELECT 4;")
  local user_mapping = function() end
  vim.keymap.set("n", "BB", user_mapping, { buffer = unnamed })
  editor:namespace_remove_note("first", unnamed_id)
  assert(vim.fn.filereadable(saved) == 1)
  assert(vim.api.nvim_buf_call(unnamed, function()
    return vim.fn.maparg("BB", "n", false, true).callback
  end) == user_mapping, "Detach must preserve mappings changed after attachment")
  local scratch = editor:namespace_create_note("global", "scratch")
  assert(not editor:search_note(scratch).external)
  editor:namespace_remove_note("global", scratch)
  print("PASS: project buffers, original saves, execution, selection, rebinding, detach, wipe, scratchpads")
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
