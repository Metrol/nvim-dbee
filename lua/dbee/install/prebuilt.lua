local M = {}

---Download the backend matching this plugin release; never compile implicitly.
function M.install(preferred)
  local install = require("dbee.install")
  local manifest = require("dbee.install.__manifest")
  local uname = (vim.uv or vim.loop).os_uname()
  local arch = ({ x86_64 = "amd64", aarch64 = "arm64" })[uname.machine] or uname.machine
  local platform = uname.sysname:lower() .. "/" .. arch
  local url = manifest.urls[platform]
  if not url then
    error(
      "DBee has no prebuilt backend for "
        .. platform
        .. '. Developers can build explicitly with require("dbee").install("go").'
    )
  end
  local downloader = preferred
  if not downloader then
    downloader = vim.fn.executable("curl") == 1 and "curl" or "wget"
  end
  for _, command in ipairs { downloader, "tar", "sha256sum" } do
    if vim.fn.executable(command) ~= 1 then
      error("DBee installation requires " .. command)
    end
  end
  local uv = vim.uv or vim.loop
  vim.fn.mkdir(install.dir(), "p")
  local staging = assert(uv.fs_mkdtemp(install.dir() .. "/.install-XXXXXX"))
  local function run(args)
    local result = vim.system(args, { text = true }):wait()
    if result.code ~= 0 then
      error("DBee install failed: " .. (result.stderr or table.concat(args, " ")))
    end
    return result.stdout
  end
  local function download(source, destination)
    if downloader == "curl" then
      run {
        "curl",
        "--fail",
        "--location",
        "--silent",
        "--show-error",
        "--retry",
        "2",
        "--connect-timeout",
        "15",
        "--max-time",
        "180",
        "--output",
        destination,
        source,
      }
    else
      run { "wget", "--quiet", "--timeout=180", "--tries=3", "--output-document", destination, source }
    end
  end
  local ok, err = xpcall(function()
    local filename = url:match("([^/]+)$")
    local archive = staging .. "/" .. filename
    local checksum_file = staging .. "/SHA256SUMS"
    download(manifest.checksums_url, checksum_file)
    local expected
    for _, line in ipairs(vim.fn.readfile(checksum_file)) do
      local digest, name = line:match("^([a-fA-F0-9]+)%s+%*?(.+)$")
      if name == filename and #digest == 64 then
        expected = digest:lower()
      end
    end
    if not expected then
      error("DBee release is missing a checksum for " .. filename)
    end
    download(url, archive)
    local actual = run({ "sha256sum", archive }):match("^([a-fA-F0-9]+)")
    if not actual or actual:lower() ~= expected then
      error("DBee backend checksum mismatch; existing binary was kept")
    end
    run { "tar", "-xzf", archive, "-C", staging, "dbee" }
    local binary = staging .. "/dbee"
    assert(uv.fs_chmod(binary, 493)) -- 0755
    assert(uv.fs_rename(binary, install.bin()))
  end, debug.traceback)
  vim.fn.delete(staging, "rf")
  if not ok then
    error(err)
  end
  print("[dbee install]: installed " .. manifest.version .. " for " .. platform)
end

return M
