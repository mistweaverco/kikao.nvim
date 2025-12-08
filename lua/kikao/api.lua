local M = {}
local Config = require("kikao.config")

M.setup = function(config)
  Config.setup(config)
end

---Clears cached data for the current project and closes all Kikao buffers.
M.clear = function()
  local utils = require("lua.kikao.config.utils")
  local project_root = utils.get_root_dir(Config.options.project_dir_matchers)
  local project_cache_dir = utils.get_cache_dir(project_root)
  if project_cache_dir and utils.file_exists(project_cache_dir) then
    vim.fn.delete(project_cache_dir, "rf")
  end
  for _, buf in pairs(vim.fn.getbufinfo()) do
    vim.api.nvim_buf_delete(buf.bufnr, { force = true })
  end
end

---Clears all cached data and closes all Kikao buffers.
M.clear_all = function()
  local utils = require("lua.kikao.config.utils")
  local all_cache_dir = utils.get_cache_dir()
  if all_cache_dir and utils.file_exists(all_cache_dir) then
    vim.fn.delete(all_cache_dir, "rf")
  end
  for _, buf in pairs(vim.fn.getbufinfo()) do
    vim.api.nvim_buf_delete(buf.bufnr, { force = true })
  end
end

return M
