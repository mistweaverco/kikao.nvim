local M = {}

---@class KikaoPickerOpts
---@field prompt? string

---@param items string[]
---@param opts KikaoPickerOpts
---@param on_choice fun(item: string|nil)
local function select_fzf_lua(items, opts, on_choice)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok or type(fzf.fzf_exec) ~= "function" then return false end
  fzf.fzf_exec(items, {
    prompt = (opts.prompt or "Select") .. "> ",
    previewer = false,
    no_hide = true,
    actions = {
      ["default"] = function(selected)
        local line = selected and selected[1] or nil
        if type(line) == "string" then line = line:gsub("\27%[[0-9;]*m", "") end
        on_choice(line)
      end,
    },
  })
  return true
end

---@param items string[]
---@param opts KikaoPickerOpts
---@param on_choice fun(item: string|nil)
local function select_fzf_vim(items, opts, on_choice)
  if vim.fn.exists("*fzf#run") ~= 1 then return false end
  local prompt = opts.prompt or "Select"
  vim.fn["fzf#run"]({
    source = items,
    sink = function(line) on_choice(line) end,
    options = "--prompt=" .. vim.fn.shellescape(prompt .. "> "),
  })
  return true
end

---@param items string[]
---@param opts KikaoPickerOpts
---@param on_choice fun(item: string|nil)
local function select_mini_pick(items, opts, on_choice)
  local ok, mini_pick = pcall(require, "mini.pick")
  if not ok or type(mini_pick.start) ~= "function" then return false end
  local choice = mini_pick.start({
    source = {
      name = opts.prompt or "Select",
      items = items,
    },
  })
  on_choice(type(choice) == "string" and choice or nil)
  return true
end

---@param items string[]
---@param opts KikaoPickerOpts
---@param on_choice fun(item: string|nil)
local function select_telescope(items, opts, on_choice)
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  local ok_finders, finders = pcall(require, "telescope.finders")
  local ok_conf, conf = pcall(require, "telescope.config")
  if not (ok_pickers and ok_finders and ok_conf) then return false end
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  pickers
    .new({}, {
      prompt_title = opts.prompt or "Select",
      finder = finders.new_table({ results = items }),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          local value = selection and (selection[1] or selection.value) or nil
          on_choice(type(value) == "string" and value or nil)
        end)
        return true
      end,
    })
    :find()
  return true
end

---@param items string[]
---@param opts KikaoPickerOpts
---@param on_choice fun(item: string|nil)
local function select_builtin(items, opts, on_choice)
  require("kikao.picker.builtin").open({
    prompt = opts.prompt or "Select",
    entries = items,
    on_select = on_choice,
  })
  return true
end

---Pick from a list of strings using the first available picker backend.
---@param items string[]
---@param opts KikaoPickerOpts|nil
---@param on_choice fun(item: string|nil)
function M.select(items, opts, on_choice)
  opts = opts or {}
  if select_fzf_lua(items, opts, on_choice) then return end
  if select_fzf_vim(items, opts, on_choice) then return end
  if select_mini_pick(items, opts, on_choice) then return end
  if select_telescope(items, opts, on_choice) then return end
  select_builtin(items, opts, on_choice)
end

return M
