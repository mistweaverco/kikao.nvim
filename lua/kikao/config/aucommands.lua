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

local vim_enter_cb = function(data, config, session_file_path, ps)
  local file_path_rel = vim.fn.fnamemodify(data.file, ":~:.:p")
  if data.file and vim.tbl_contains(config.deny_on_path, file_path_rel) then
    return
  end

  local dir = vim.fn.getcwd()

  for _, root in ipairs(config.project_dir_matchers) do
    if vim.fn.isdirectory(dir .. ps .. root) == 1 then
      save_session = true
      break
    end
  end

  if save_session then
    if vim.fn.filereadable(session_file_path) == 1 then
      vim.cmd("source " .. session_file_path)
      if data.file then
        vim.cmd("e " .. data.file)
      end
    end
  end
end

M.setup = function(config)
  local ps = package.config:sub(1, 1)
  local augroup = vim.api.nvim_create_augroup("KikaoSession", { clear = true })
  local session_file_path = config.session_file_path
  if session_file_path == nil then
    session_file_path = vim.fn.getcwd() .. ps .. ".editor" .. ps .. "neovim-session.vim"
  else
    session_file_path = session_file_path:gsub("{{PROJECT_DIR}}", vim.fn.getcwd())
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function(data)
      vim_enter_cb(data, config, session_file_path, ps)
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
