local Utils = require("kikao.config.utils")
local M = {}

local remove_buffers_on_deny_path = function(config)
  for _, pattern in ipairs(config.deny_on_path) do
    local buf_ids = vim.fn.getbufinfo()
    for _, buf in ipairs(buf_ids) do
      local buf_name = vim.fn.fnamemodify(buf.name, ":~:.:p")
      --- Remove buffer if it matches the deny pattern or is unlisted
      if buf_name:match(pattern) or buf.listed == 0 then
        vim.api.nvim_buf_delete(buf.bufnr, { force = true })
      end
    end
  end
end

local vim_leave_cb = function(config, session_file_path, project_dir)
  local session_file = Utils.join_paths(session_file_path, config.session_file_name)
  remove_buffers_on_deny_path(config)
  if Utils.is_empty_or_start_buffer() then
    if vim.fn.filereadable(session_file) == 1 then
      vim.fn.delete(session_file)
    end
  else
    vim.cmd("mksession! " .. session_file)
  end

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
  local session_file = Utils.join_paths(session_file_path, config.session_file_name)

  if vim.fn.filereadable(session_file) == 1 then
    -- Check if the session file is not empty
    local session_file_size = vim.fn.getfsize(session_file)
    if session_file_size > 0 then
      -- Store the current working directory before sourcing the session
      -- Session files can change the cwd, so we need to restore it afterward
      local original_cwd = vim.fn.getcwd()

      -- Try to source the session file safely
      local ok, err = pcall(function()
        vim.cmd("silent! source " .. session_file)
      end)
      if not ok then
        vim.notify("Failed to restore session: " .. err, vim.log.levels.WARN)
      else
        -- Restore the original working directory after sourcing the session
        vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
      end

      if data.file then
        vim.cmd("e " .. data.file)
      end
    end
  end
end

M.setup = function(config)
  -- Prevent sourcing at all when run via git mergetool
  if Utils.is_git_mergetool() then
    return
  end

  local augroup = vim.api.nvim_create_augroup("com.mistweaverco.apps.neovim.kikao", { clear = true })
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
      -- Disable on diff conflicts.nvim buffers
      if Utils.is_diffconflicts_buffer() then
        return
      end
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
      -- Disable on diff conflicts.nvim buffers
      -- Check all buffers to see if any are diffconflicts buffers
      local has_diffconflicts = false
      for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
        if Utils.is_diffconflicts_buffer(buf.bufnr) then
          has_diffconflicts = true
          break
        end
      end
      if has_diffconflicts then
        return
      end
      vim_leave_cb(config, session_file_path, project_dir)
    end,
    group = augroup,
  })
end

return M
