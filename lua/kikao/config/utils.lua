local M = {}
local IS_WINDOWS = vim.uv.os_uname().version:match("Windows")

M.join_paths = function(...)
  local paths = { ... }
  return table.concat(paths, IS_WINDOWS and "\\" or "/")
end

-- get kikao cache dir
--- @param path string|nil optional path to append as hash subdir
--- @return string|nil
--- @usage local cache_dir = utils.get_cache_dir()
M.get_cache_dir = function(path)
  local cache = vim.fn.stdpath("cache")
  if cache == "" then return nil end
  local cache_dir = M.join_paths(cache, "kikao.nvim")
  if path then
    local hash = vim.fn.sha256(path)
    cache_dir = M.join_paths(cache, "kikao.nvim", hash)
  end
  if not M.file_exists(cache_dir) then
    if vim.fn.mkdir(cache_dir, "p") == 0 then return nil end
  end
  return cache_dir
end

---Get project root directory
---@param markers table|nil optional list of project dir markers
---@return string|nil project root directory if found, else nil
---@usage local root_dir = utils.get_root_dir({'.git', 'package.json'})
M.get_root_dir = function(markers)
  if markers == nil then
    return M.get_nearest_vcs_root()
  else
    local finder = M.find_first_in_parent_dirs(markers, "directory")
    if finder == nil then return nil end
    -- get parent directory of finder
    local dir = vim.fs.dirname(finder)
    -- return absolute path
    return vim.fn.fnamemodify(dir, ":p")
  end
end

-- find nearest file in parent directories, starting from the current buffer file path
--- @param name string|table file or list of files to search for
--- @param type string|nil 'file'|'directory' ( defaults to 'file' )
--- @return string|nil
--- @usage local p = utils.find_first_in_parent_dirs('.git', 'directory')
M.find_first_in_parent_dirs = function(name, type)
  type = type or "file"
  return vim.fs.find(name, {
    type = type,
    upward = true,
    limit = 1,
    path = M.get_current_buffer_dir(),
  })[1]
end

M.get_current_buffer_dir = function()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == "" then
    return vim.uv.cwd()
  else
    return vim.fs.dirname(buf_path)
  end
end

M.file_exists = function(path) return vim.fn.filereadable(path) == 1 end
M.dir_exists = function(path) return vim.fn.isdirectory(path) == 1 end

M.get_file_contents = function(file_path)
  local filehandle = io.open(file_path, "r")
  if not filehandle then return nil end
  local content = filehandle:read("*a")
  filehandle:close()
  return content
end

M.get_json_file_contents = function(file_path)
  local content = M.get_file_contents(file_path)
  if not content then return nil end
  content = content == "" and "{}" or content
  return vim.json.decode(content)
end

---Write project metadata to cache
---@param project_root string project root directory
---@param metadata table metadata to write
---@return boolean success
M.write_project_metadata = function(project_root, metadata)
  local metadata_file_path = M.join_paths(M.get_cache_dir(project_root), "metadata.json")
  local new_metadata

  if M.file_exists(metadata_file_path) then
    local old_metadata = M.get_json_file_contents(metadata_file_path)
    if not old_metadata then return false end
    new_metadata = vim.tbl_deep_extend("force", old_metadata, metadata)
  else
    new_metadata = metadata
  end
  return M.write_file(metadata_file_path, vim.json.encode(new_metadata))
end

---Get project metadata from cache
---@param project_root string project root directory
---@return table|nil metadata if exists, else nil
M.get_project_metadata = function(project_root)
  local metadata_file_path = M.join_paths(M.get_cache_dir(project_root), "metadata.json")
  if not M.file_exists(metadata_file_path) then return nil end
  return M.get_json_file_contents(metadata_file_path)
end

---Given a table and a dot notation key, returns the part of the table
---@param tbl table the table to access
---@param key string dot notation key
---@return table|nil the value at the dot notation key, or nil if not found
M.resolve_dot_notation_for_table = function(tbl, key)
  local parts = {}
  for part in string.gmatch(key, "[^%.]+") do
    table.insert(parts, part)
  end
  local current = tbl
  for _, part in ipairs(parts) do
    if type(current) ~= "table" then return nil end
    current = current[part]
    if current == nil then return nil end
  end
  return current
end

---Check if current buffers are empty,
---not counting unlisted buffers,
---or only the start buffer is open
---@return boolean
M.is_empty_or_start_buffer = function()
  local buf_info = vim.fn.getbufinfo({ buflisted = 1 })
  if #buf_info == 0 then
    return true
  elseif #buf_info == 1 then
    local buf = buf_info[1]
    if vim.fn.getbufline(buf.bufnr, 1)[1] == "" then return true end
  end
  return false
end

---Write content to a file
---@param file_path string full path to the file
---@param content string content to write
---@return boolean success
M.write_file = function(file_path, content)
  local filehandle = io.open(file_path, "w")
  if not filehandle then return false end
  filehandle:write(content)
  filehandle:close()
  return true
end

---Append content to a file
---@param file_path string full path to the file
---@param content string content to append
---@return boolean success
M.append_contents_to_file = function(file_path, content)
  local filehandle = io.open(file_path, "a")
  if not filehandle then return false end
  filehandle:write(content)
  filehandle:close()
  return true
end

M.get_nearest_vcs_root = function()
  local vcs_dir = M.find_first_in_parent_dirs({ ".git", ".hg", ".jj" }, "directory")
  if vcs_dir == nil then return nil end
  -- get parent directory of vcs_dir
  local dir = vim.fs.dirname(vcs_dir)
  -- return absolute path
  return vim.fn.fnamemodify(dir, ":p")
end

---Check if running via git mergetool
---@return boolean
M.is_git_mergetool = function()
  -- Check environment variables set by git mergetool
  -- GIT_MERGETOOL is set by git when running mergetool
  if vim.env.GIT_MERGETOOL or vim.env.GIT_MERGE_TOOL then return true end
  return false
end

---Check if current buffer is a diffconflicts.nvim buffer
---@param bufnr number|nil optional buffer number, defaults to current buffer
---@return boolean
M.is_diffconflicts_buffer = function(bufnr)
  bufnr = bufnr or 0
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if buf_name == "" then return false end
  -- diffconflicts.nvim creates buffers with .LOCAL., .BASE., or .REMOTE. in the name
  if buf_name:match("%.LOCAL%.") or buf_name:match("%.BASE%.") or buf_name:match("%.REMOTE%.") then return true end
  return false
end

---@class SessionSavePathInfo
---@field session_file_path string full path to session file
---@field project_root string project root directory

---Get session save path
---@param markers table|nil optional list of project dir markers
---@return SessionSavePathInfo|nil
M.get_session_save_path_info = function(markers)
  local root_dir = M.get_root_dir(markers)
  if root_dir == nil then return nil end
  local session_dir = M.get_cache_dir(root_dir)
  if session_dir == nil then return nil end
  local session_file_path = session_dir
  return {
    session_file_path = session_file_path,
    project_root = root_dir,
  }
end

return M
