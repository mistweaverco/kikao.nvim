local Globals = require("kikao.globals")
local Config = require("kikao.config")
local Logger = require("kikao.logger")
local M = {}

M.setup = function(config)
  Config.setup(config)
end

M.version = function()
  local neovim_version = vim.fn.execute("version") or "Unknown"
  Logger.info("Kikao version: " .. Globals.VERSION .. "\n\n" .. "Neovim version: " .. neovim_version)
end

return M
