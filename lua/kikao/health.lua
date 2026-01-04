local Globals = require("kikao.globals")

local health = vim.health
local info = health.info

local M = {}

M.check = function() info("{kikao.nvim} version " .. Globals.VERSION) end

return M
