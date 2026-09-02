local Logger = require("kikao.logger")
local Utils = require("kikao.config.utils")

local M = {}

---When set, the next `save()` call is a no-op (used so VimLeave during `:restart`
---does not write the old session into the destination project).
local skip_next_save = false

---@param path string
---@return string
local function normalize_dir(path)
  local abs = vim.fn.fnamemodify(path, ":p")
  return abs:gsub("[\\/]+$", "")
end

---@return boolean
local function has_unsaved()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified and vim.bo[buf].buftype == "" then return true end
  end
  return false
end

---@param config KikaoActiveConfig
local function remove_buffers_on_deny_path(config)
  for _, pattern in ipairs(config.deny_on_path) do
    local buf_ids = vim.fn.getbufinfo()
    for _, buf in ipairs(buf_ids) do
      local buf_name = vim.fn.fnamemodify(buf.name, ":~:.:p")
      if buf_name:match(pattern) or buf.listed == 0 then
        -- Picker/terminal buffers may still be tearing down; never block the switch.
        pcall(vim.api.nvim_buf_delete, buf.bufnr, { force = true })
      end
    end
  end
end

---Neovim-owned env that must not leak into a nested editor or be clobbered by a shell dump.
---@param key string
---@return boolean
local function is_nvim_internal(key)
  return key == "NVIM"
    or key == "NVIM_LISTEN_ADDRESS"
    or key == "VIM"
    or key == "VIMRUNTIME"
    or key == "MYVIMRC"
    or key == "VIMINIT"
end

---Snapshot env as if the user opened a login/interactive shell and `cd`'d into `dir`.
---That runs whatever the shell would normally run (direnv, mise, nvm, chpwd hooks, ...).
---@param dir string
---@return table<string, string>|nil
local function capture_login_env(dir)
  local shell = vim.env.SHELL or "/bin/sh"
  local seed = {}
  for key, value in pairs(vim.fn.environ()) do
    if not is_nvim_internal(key) then seed[key] = value end
  end
  local cmdline = "cd " .. vim.fn.shellescape(dir) .. " && env -0"
  local result = vim
    .system({ shell, "-lic", cmdline }, {
      env = seed,
      text = true,
      stdin = "ignore",
      timeout = 15000,
    })
    :wait()
  if not result or result.code ~= 0 or type(result.stdout) ~= "string" or result.stdout == "" then return nil end

  local captured = {}
  for entry in result.stdout:gmatch("([^%z]+)") do
    local eq = entry:find("=", 1, true)
    if eq then captured[entry:sub(1, eq - 1)] = entry:sub(eq + 1) end
  end
  if vim.tbl_isempty(captured) then return nil end
  return captured
end

---Replace this process env with a login-shell snapshot (keep Neovim internals).
---@param captured table<string, string>
local function apply_login_env(captured)
  for key in pairs(vim.fn.environ()) do
    if not is_nvim_internal(key) and captured[key] == nil then vim.env[key] = nil end
  end
  for key, value in pairs(captured) do
    if not is_nvim_internal(key) then vim.env[key] = value end
  end
end

---After this process exits, start nvim via a login/interactive shell on the real TTY.
---Used when `:restart` is unavailable (Neovim < 0.12).
---@param dir string
local function reopen_after_exit(dir)
  local pid = vim.uv.os_getpid()
  local nvim = vim.v.progpath
  local shell = vim.env.SHELL or "/bin/sh"
  local inner = "cd " .. vim.fn.shellescape(dir) .. " && exec " .. vim.fn.shellescape(nvim)
  local script = string.format(
    "while kill -0 %d 2>/dev/null; do sleep 0.05; done; exec %s -lic %s </dev/tty >/dev/tty 2>/dev/tty",
    pid,
    vim.fn.shellescape(shell),
    vim.fn.shellescape(inner)
  )
  vim.system({ "/bin/sh", "-c", script }, { detach = true })
end

---Persist the current session (deny-path cleanup, mksession, metadata).
---@param config KikaoActiveConfig|KikaoDefaultConfig
---@param session_file_path string
---@param project_dir string|nil
function M.save(config, session_file_path, project_dir)
  if skip_next_save then
    skip_next_save = false
    return
  end
  local session_file = Utils.join_paths(session_file_path, config.session_file_name)
  remove_buffers_on_deny_path(config)
  if Utils.is_empty_or_start_buffer() then
    if vim.fn.filereadable(session_file) == 1 then vim.fn.delete(session_file) end
  else
    pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_file))
  end

  if project_dir then Utils.write_project_metadata(project_dir, { project_dir = project_dir }) end
end

---Recompute the current project and persist its session.
function M.save_current()
  local config = require("kikao.config").get()
  local session_file_path
  local project_dir
  if config.session_file_path == nil then
    local info = Utils.get_session_save_path_info(config.project_dir_matchers)
    if not info then return end
    project_dir = info.project_root
    session_file_path = info.session_file_path
  else
    session_file_path = config.session_file_path:gsub("{{PROJECT_DIR}}", vim.fn.getcwd())
  end
  M.save(config, session_file_path, project_dir)
end

---@class KikaoSession
---@field project_dir string
---@field display string
---@field current boolean

---List known sessions from cache metadata.
---@return KikaoSession[]
function M.list()
  local cache = vim.fn.stdpath("cache")
  if cache == "" then return {} end
  local root = Utils.join_paths(cache, "kikao.nvim")
  local files = vim.fn.glob(Utils.join_paths(root, "*", "metadata.json"), true, true)
  if type(files) ~= "table" then return {} end

  local config = require("kikao.config").get()
  local current_root = Utils.get_root_dir(config.project_dir_matchers)
  local current_key = current_root and normalize_dir(current_root) or nil

  local seen = {}
  local sessions = {}
  for _, meta_file in ipairs(files) do
    local ok, metadata = pcall(Utils.get_json_file_contents, meta_file)
    if ok and type(metadata) == "table" and type(metadata.project_dir) == "string" then
      local project_dir = metadata.project_dir
      if Utils.dir_exists(project_dir) then
        local key = normalize_dir(project_dir)
        if key ~= "" and not seen[key] then
          seen[key] = true
          local is_current = current_key == key
          local home_path = vim.fn.fnamemodify(project_dir, ":~")
          table.insert(sessions, {
            project_dir = project_dir,
            display = is_current and (home_path .. "  *") or home_path,
            current = is_current,
          })
        end
      end
    end
  end

  table.sort(sessions, function(a, b)
    if a.current ~= b.current then return a.current end
    return a.display < b.display
  end)

  return sessions
end

---Switch to a project's session by restarting Neovim in that directory.
---@param project_dir string
function M.switch(project_dir)
  if not project_dir or project_dir == "" then return end
  local dest = vim.fn.fnamemodify(project_dir, ":p")
  if vim.fn.isdirectory(dest) == 0 then
    Logger.error("Project directory does not exist: " .. project_dir)
    return
  end

  local config = require("kikao.config").get()
  local current_root = Utils.get_root_dir(config.project_dir_matchers)
  local current_key = current_root and normalize_dir(current_root) or normalize_dir(vim.fn.getcwd())
  if current_key == normalize_dir(dest) then
    Logger.info("Already in this session")
    return
  end

  if vim.fn.has("win32") == 1 then
    Logger.error("Session switch restart is not supported on Windows")
    return
  end

  if has_unsaved() then
    local choice = vim.fn.confirm("Unsaved changes", "&Save all\n&Discard changes\n&Abort", 3, "Question")
    if choice == 0 or choice == 3 then return end
    if choice == 1 then
      local ok, err = pcall(function() vim.cmd("silent wall") end)
      if not ok then
        Logger.error("Failed to save buffers: " .. tostring(err))
        return
      end
    end
  end

  -- Save the *current* project first. Then skip VimLeave so `:restart` / `:qa`
  -- cannot write these buffers into the destination session after chdir.
  M.save_current()
  skip_next_save = true

  local captured = capture_login_env(dest)
  if captured then
    apply_login_env(captured)
  else
    Logger.warn("Could not capture login shell environment; restarting with current env")
  end
  vim.fn.chdir(dest)

  -- `:restart` is the supported way to replace this UI. ffi execvp aborts
  -- Neovim (SIGABRT / exit 134) because of libuv worker threads.
  if vim.fn.exists(":restart") == 2 then
    vim.cmd("restart! +qall!")
    return
  end

  reopen_after_exit(dest)
  vim.cmd("qall!")
end

---Open a fuzzy picker of known sessions and switch on selection.
function M.pick()
  local sessions = M.list()
  if #sessions == 0 then
    Logger.warn("No Kikao sessions found")
    return
  end

  local items = {}
  local by_display = {}
  for _, session in ipairs(sessions) do
    table.insert(items, session.display)
    by_display[session.display] = session.project_dir
    by_display[vim.fn.fnamemodify(session.project_dir, ":~")] = session.project_dir
  end

  require("kikao.picker").select(items, { prompt = "Kikao sessions" }, function(choice)
    if type(choice) ~= "string" or choice == "" then return end
    local cleaned = choice:gsub("\27%[[0-9;]*m", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+%*$", "")
    local dir = by_display[choice] or by_display[cleaned]
    if not dir then
      Logger.warn("Could not resolve session: " .. cleaned)
      return
    end
    vim.schedule(function() M.switch(dir) end)
  end)
end

return M
