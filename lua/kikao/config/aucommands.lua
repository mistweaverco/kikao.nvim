local Utils = require("kikao.config.utils")
local M = {}

local vim_leave_cb = function(config, session_file_path, project_dir)
  local session_file = Utils.join_paths(session_file_path, config.session_file_name)
  vim.cmd("mksession! " .. session_file)
  -- INFO:
  -- Could be empty if session_file_path is managed by user
  if project_dir then
    -- Save project metadata
    -- This is used to identify the project directory
    -- because we might want to have a session picker in the future
    Utils.write_project_metadata(project_dir, { project_dir = project_dir })
  end
end

local vim_enter_cb = function(config, data, session_file_path)
  local file_path_rel = vim.fn.fnamemodify(data.file, ":~:.:p")
  if data.file and vim.tbl_contains(config.deny_on_path, file_path_rel) then
    return
  end

  local session_file = Utils.join_paths(session_file_path, config.session_file_name)

  if vim.fn.filereadable(session_file) == 1 then
    -- Check if the session file is not empty
    local session_file_size = vim.fn.getfsize(session_file)
    if session_file_size > 0 then
      -- Try to source the session file safely
      local ok, err = pcall(function()
        vim.cmd("silent! source " .. session_file)
      end)
      if not ok then
        vim.notify("Failed to restore session: " .. err, vim.log.levels.WARN)
      end

      if data.file then
        vim.cmd("e " .. data.file)
      end
    end
  end
end

M.setup = function(config)
  local augroup = vim.api.nvim_create_augroup("KikaoSession", { clear = true })
  local session_file_path
  local project_dir
  if config.session_file_path == nil then
    local session_file_path_info = Utils.get_session_save_path_info(config.project_dir_matchers)
    if session_file_path_info == nil then
      return
    end
    project_dir = session_file_path_info.project_root
    session_file_path = session_file_path_info.session_file_path
  else
    session_file_path = config.session_file_path:gsub("{{PROJECT_DIR}}", vim.fn.getcwd())
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function(data)
      -- Call the session restoration function
      pcall(function()
        vim_enter_cb(config, data or {}, session_file_path)
      end)
    end,
    group = augroup,
    nested = true,
  })

  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      vim_leave_cb(config, session_file_path, project_dir)
    end,
    group = augroup,
  })
end

return M
