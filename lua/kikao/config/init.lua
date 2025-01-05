local AuCommands = require("kikao.config.aucommands")
local M = {}

M.defaults = {
  project_dir_matchers = { ".editor" },
  session_file_path = nil,
  deny_on_path = {
    ".git/COMMIT_EDITMSG",
  },
}

M.options = M.defaults

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
  AuCommands.setup(M.options)
end

M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

M.get = function()
  return M.options
end

return M
