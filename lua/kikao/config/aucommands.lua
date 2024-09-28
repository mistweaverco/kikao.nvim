local M = {}

local save_session = false

local vim_leave_cb = function(session_file_path)
  if save_session == false then
    return
  end
  local sessiondir = vim.fn.fnamemodify(session_file_path, ":h")
  vim.fn.mkdir(sessiondir, "p")
  vim.cmd("mksession! " .. session_file_path)
end

local vim_enter_cb = function(data, project_dir_matchers, session_file_path, ps)
  if data.file and vim.fn.filereadable(data.file) == 1 then
    return
  end

  local dir = vim.fn.getcwd()

  for _, root in ipairs(project_dir_matchers) do
    if vim.fn.isdirectory(dir .. ps .. root) == 1 then
      save_session = true
      break
    end
  end

  if save_session then
    if vim.fn.filereadable(session_file_path) == 1 then
      vim.cmd("source " .. session_file_path)
    end
  end
end

M.setup = function(config)
  local ps = package.config:sub(1, 1)
  local augroup = vim.api.nvim_create_augroup("KikaoSession", { clear = true })
  local session_file_path = config.session_file_path
  if session_file_path == nil then
    session_file_path = vim.fn.getcwd() .. ps .. ".nvim" .. ps .. "session.vim"
  else
    session_file_path = session_file_path:gsub("{{PROJECT_DIR}}", vim.fn.getcwd())
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function(data)
      vim_enter_cb(data, config.project_dir_matchers, session_file_path, ps)
    end,
    group = augroup,
    nested = true,
  })

  vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
      vim_leave_cb(session_file_path)
    end,
    group = augroup,
  })
end

return M
