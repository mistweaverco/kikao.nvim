---@class KikaoConfig
---@field key string The key of the option to set.
---@field value any The value to set the option to.

local AuCommands = require("kikao.config.aucommands")

local M = {}

---@class KikaoDefaultConfig
---@field project_dir_matchers string[] List of directory names to identify the project root
---@field session_file_path string|nil Custom session file path, supports {{PROJECT_DIR}} placeholder
---@field session_file_name string Name of the session file to save/load
---@field deny_on_path string[] List of path patterns to deny session restoration

---@class KikaoActiveConfig: KikaoDefaultConfig

---@class KikaoUserConfig
---@field project_dir_matchers string[]|nil List of directory names to identify the project root
---@field session_file_path string|nil Custom session file path, supports {{PROJECT_DIR}} placeholder
---@field session_file_name string|nil Name of the session file to save/load
---@field deny_on_path string[]|nil List of path patterns to deny session restoration

---@type KikaoDefaultConfig
M.defaults = {
  project_dir_matchers = { ".git", ".svn", ".jj", ".hg" },
  session_file_path = nil,
  session_file_name = "session.vim",
  deny_on_path = {
    ".git/COMMIT_EDITMSG",
    ".git/rebase-merge/git-rebase-todo",
    "NeovimTree_",
    "fugitive://",
    "git://",
    "term://",
    "toggleterm://",
    "dap-repl://",
    "dapui://",
    "kulala://",
    "NeogitStatus",
  },
}

---@type KikaoDefaultConfig
M.options = M.defaults

---Setup Kikao with user configuration
---@param config KikaoUserConfig
---@return nil
M.setup = function(config)
  config = config or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, config)
  AuCommands.setup(M.options)
end

---Set Kikao configuration at runtime
---@param config KikaoUserConfig
M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config)
end

---Get current Kikao configuration
---@return KikaoActiveConfig
M.get = function()
  local options = M.options
  ---@cast options KikaoActiveConfig
  return options
end

return M
