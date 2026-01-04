---@class KikaoAPI
---@field setup fun(config: KikaoUserConfig): nil
---@field clear fun(): nil
---@field clear_all fun(): nil
---@field get_value fun(opts: KikaoAPIGetValueOpts): any|nil
---@field set_value fun(opts: KikaoAPISetValueOpts): boolean

local M = {}

---Setup Kikao with user configuration
---@param config KikaoUserConfig
M.setup = function(config) require("kikao.config").setup(config) end

---Clears cached data for the current project and closes all buffers.
---@return nil
M.clear = function()
  local user_config = require("kikao.config").get()
  local utils = require("kikao.config.utils")
  local project_root = utils.get_root_dir(user_config.project_dir_matchers)
  local project_cache_dir = utils.get_cache_dir(project_root)
  if project_cache_dir and utils.file_exists(project_cache_dir) then vim.fn.delete(project_cache_dir, "rf") end
  for _, buf in pairs(vim.fn.getbufinfo()) do
    vim.api.nvim_buf_delete(buf.bufnr, { force = true })
  end
end

---Clears all cached data and closes all buffers.
---@return nil
M.clear_all = function()
  local utils = require("kikao.config.utils")
  local all_cache_dir = utils.get_cache_dir()
  if all_cache_dir and utils.file_exists(all_cache_dir) then vim.fn.delete(all_cache_dir, "rf") end
  for _, buf in pairs(vim.fn.getbufinfo()) do
    vim.api.nvim_buf_delete(buf.bufnr, { force = true })
  end
end

---@class KikaoAPIGetValueOpts
---@field key string The key of the option to set.

---Gets the value of a workspace option stored in the maybe existing metadata.
---@param opts KikaoAPIGetValueOpts
---@return any|nil The value of the option, or nil if not found.
M.get_value = function(opts)
  local user_config = require("kikao.config").get()
  local utils = require("kikao.config.utils")
  local project_root = utils.get_root_dir(user_config.project_dir_matchers)
  if not project_root then return nil end
  local metadata = utils.get_project_metadata(project_root)
  if not metadata then return nil end
  return metadata[opts.key]
end

---@class KikaoAPISetValueOpts
---@field key string The key of the option to set.
---@field value any The value to set the option to.

---Sets the value of a workspace option stored in the maybe existing metadata.
---@param opts KikaoAPISetValueOpts
---@return boolean success
M.set_value = function(opts)
  local user_config = require("kikao.config").get()
  local utils = require("kikao.config.utils")
  local project_root = utils.get_root_dir(user_config.project_dir_matchers)
  if not project_root then return false end
  return utils.write_project_metadata(project_root, { [opts.key] = opts.value })
end

---@return KikaoAPI
return M
