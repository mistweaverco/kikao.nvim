local Api = require("kikao.api")
local Globals = require("kikao.globals")
local Logger = require("kikao.logger")
local M = {}

---Sets up Kikao with the provided configuration.
M.setup = function(config) Api.setup(config) end

---Clears cached data for the current project and closes all Kikao buffers.
M.clear = function() Api.clear() end

---Clears all cached data and closes all Kikao buffers.
M.clear_all = function() Api.clear_all() end

---Prints the current Kikao version and Neovim version to the log.
M.version = function()
  local neovim_version = vim.fn.execute("version") or "Unknown"
  Logger.info("Kikao version: " .. Globals.VERSION .. "\n\n" .. "Neovim version: " .. neovim_version)
end

return M
