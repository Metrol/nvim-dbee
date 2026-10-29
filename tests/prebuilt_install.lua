-- nvim --headless -u NONE -i NONE -l tests/prebuilt_install.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local ok, err = xpcall(function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/fixture", "p")
  vim.fn.writefile({ "fixture backend" }, root .. "/fixture/dbee")
  local archive = root .. "/dbee_linux_amd64.tar.gz"
  assert(vim.system({ "tar", "-czf", archive, "-C", root .. "/fixture", "dbee" }):wait().code == 0)
  local digest = vim.system({ "sha256sum", archive }, { text = true }):wait().stdout:match("^%x+")
  local checksums = root .. "/SHA256SUMS"
  vim.fn.writefile({ digest .. "  dbee_linux_amd64.tar.gz" }, checksums)
  local install = require("dbee.install")
  install.dir = function()
    return root .. "/bin"
  end
  package.loaded["dbee.install.__manifest"] = {
    version = "test",
    checksums_url = "https://example.invalid/SHA256SUMS",
    urls = { ["linux/amd64"] = "https://example.invalid/dbee_linux_amd64.tar.gz" },
  }
  local original = vim.system
  local downloads, fail = 0, false
  vim.system = function(args, opts)
    assert(args[1] ~= "go", "The download installer must never compile")
    if args[1] ~= "curl" then
      return original(args, opts)
    end
    downloads = downloads + 1
    local destination
    for index, value in ipairs(args) do
      if value == "--output" then
        destination = args[index + 1]
      end
    end
    local source = args[#args]:match("SHA256SUMS$") and checksums or archive
    if not fail then
      assert((vim.uv or vim.loop).fs_copyfile(source, destination))
    end
    return {
      wait = function()
        return { code = fail and 22 or 0, stdout = "", stderr = fail and "download failed" or "" }
      end,
    }
  end
  install.exec()
  assert(downloads == 2 and vim.fn.readfile(install.bin())[1] == "fixture backend")
  vim.fn.writefile({ "existing backend" }, install.bin())
  vim.fn.writefile({ string.rep("0", 64) .. "  dbee_linux_amd64.tar.gz" }, checksums)
  local success, message = pcall(install.exec)
  assert(not success and message:find("checksum mismatch", 1, true))
  assert(vim.fn.readfile(install.bin())[1] == "existing backend")
  fail = true
  assert(not pcall(install.exec))
  assert(vim.fn.readfile(install.bin())[1] == "existing backend")
  local manifest = package.loaded["dbee.install.__manifest"]
  manifest.urls = {}
  assert(not pcall(install.exec))
  assert(vim.fn.readfile(install.bin())[1] == "existing backend")
  assert(#vim.fn.glob(root .. "/bin/.install-*", false, true) == 0, "Staging directories must be cleaned")
  vim.system = original
  vim.fn.delete(root, "rf")
  print(
    "PASS: prebuilt download, checksum validation, preserved existing binary on failures, unsupported platforms, no Go fallback"
  )
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
