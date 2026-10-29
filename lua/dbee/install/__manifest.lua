-- This plugin tag and backend release are published together.
local tag = "v0.2.0-metrol.1"
local release = "https://github.com/Metrol/nvim-dbee/releases/download/" .. tag
return {
  version = "v0.2.0-metrol.1",
  checksums_url = release .. "/SHA256SUMS",
  urls = {
    ["linux/amd64"] = release .. "/dbee_linux_amd64.tar.gz",
  },
}
