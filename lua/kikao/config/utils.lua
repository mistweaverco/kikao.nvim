local M = {}
local IS_WINDOWS = vim.loop.os_uname().version:match("Windows")

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
  if path then
    local hash = vim.fn.sha256(path)
    return M.join_paths(cache, "kikao.nvim", hash)
  end
  return M.join_paths(cache, "kikao.nvim")
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
    return vim.loop.cwd()
  else
    return vim.fs.dirname(buf_path)
  end
end

M.file_exists = function(path)
  return vim.loop.fs_stat(path) ~= nil
end

M.write_project_metadata = function(project_root, metadata)
  local metadata_file_path = M.join_paths(M.get_cache_dir(project_root), "metadata.json")
  local new_metadata
  local filehandle = io.open(metadata_file_path, "r+")
  if M.file_exists(metadata_file_path) then
    if not filehandle then
      return
    end
    local content = filehandle:read("*a")
    local old_metadata = vim.fn.json_decode(content) or {}
    new_metadata = vim.tbl_extend("force", old_metadata, metadata)
  else
    new_metadata = metadata
  end
  if not filehandle then
    return
  end
  filehandle:write(vim.fn.json_encode(new_metadata))
  filehandle:close()
end

---Write content to a file
---@param file_path string full path to the file
---@param content string content to write
---@return boolean success
M.write_file = function(file_path, content)
  local filehandle = io.open(file_path, "w")
  if not filehandle then
    return false
  end
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
  if not filehandle then
    return false
  end
  filehandle:write(content)
  filehandle:close()
  return true
end

M.get_nearest_vcs_root = function()
  return M.find_first_in_parent_dirs({ ".git", ".hg", ".jj" }, "directory")
end

---@class SessionSavePathInfo
---@field session_file_path string full path to session file
---@field project_root string project root directory

---Get session save path
---@param markers table|nil optional list of project dir markers
---@return SessionSavePathInfo|nil
M.get_session_save_path_info = function(markers)
  local root_dir
  if markers ~= nil then
    root_dir = M.find_first_in_parent_dirs(markers, "directory")
  else
    root_dir = M.get_nearest_vcs_root()
  end
  if root_dir == nil then
    return nil
  end
  local session_dir = M.get_cache_dir(root_dir)
  if session_dir == nil then
    return nil
  end
  vim.fn.mkdir(session_dir, "p")
  local session_file_path = session_dir
  return {
    session_file_path = session_file_path,
    project_root = root_dir,
  }
end

return M
