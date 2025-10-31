local AuCommands = require("kikao.config.aucommands")
local M = {}

M.defaults = {
  project_dir_matchers = { ".git", ".svn", ".jj", ".hg" },
  session_file_path = nil,
  session_file_name = "session.vim",
  deny_on_path = {
    ".git/COMMIT_EDITMSG",
  },
}

M.options = M.defaults

M.setup = function(config)
  config = config or {}
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
