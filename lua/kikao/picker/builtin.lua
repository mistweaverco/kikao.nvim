-- Fuzzy finder adapted from jujutsu.nvim (MIT, Copyright 2026+ The Don't Be Evil Company)

local M = {}

---@param needle string
---@param haystack string
---@return number|nil
local function score_match(needle, haystack)
  if needle == "" then return 0 end
  needle, haystack = needle:lower(), haystack:lower()
  local ni, score, prev = 1, 0, 0
  for hi = 1, #haystack do
    if haystack:sub(hi, hi) == needle:sub(ni, ni) then
      score = score + 1
      if prev + 1 == hi then score = score + 2 end
      if hi == 1 or haystack:sub(hi - 1, hi - 1):match("[%s%p_/]") then score = score + 3 end
      prev = hi
      ni = ni + 1
      if ni > #needle then return score - (#haystack - #needle) * 0.01 end
    end
  end
  return nil
end

---@class KikaoBuiltinPickerOpts
---@field prompt? string
---@field entries string[]
---@field on_select fun(item: string|nil)

---@param opts KikaoBuiltinPickerOpts
function M.open(opts)
  local prompt = opts.prompt or "select"
  local entries = {}
  for _, e in ipairs(opts.entries or {}) do
    table.insert(entries, tostring(e))
  end

  local query, cursor = "", 1
  local filtered = {}
  local closed = false
  local result_set = false
  local result_value = nil ---@type string|nil
  local redrawing = false
  local ns = vim.api.nvim_create_namespace("kikao-finder")
  local augroup = vim.api.nvim_create_augroup("KikaoFinder" .. tostring(vim.uv.hrtime()), { clear = true })

  local height = math.max(10, math.floor(vim.o.lines * 0.4))
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].filetype = "kikao-finder"

  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = vim.o.lines - height - 2,
    col = 0,
    width = vim.o.columns,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. prompt .. " ",
    title_pos = "left",
    focusable = true,
    zindex = 200,
  })
  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].wrap = false
  vim.wo[win].signcolumn = "no"

  local function teardown()
    if closed then return end
    closed = true
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    pcall(vim.cmd, "stopinsert")
    vim.schedule(function()
      if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then pcall(vim.api.nvim_buf_delete, bufnr, { force = true }) end
      opts.on_select(result_value)
    end)
  end

  local function finish(result)
    if result_set then return end
    result_set = true
    result_value = result
    teardown()
  end

  local function abort() finish(nil) end

  local function refilter()
    filtered = {}
    for _, text in ipairs(entries) do
      local s = score_match(query, text)
      if s then table.insert(filtered, { text = text, score = s }) end
    end
    table.sort(filtered, function(a, b) return a.score > b.score end)
    cursor = math.max(1, math.min(cursor, math.max(#filtered, 1)))
  end

  local function current() return filtered[cursor] and filtered[cursor].text end

  local function redraw()
    if closed or not vim.api.nvim_buf_is_valid(bufnr) then return end
    redrawing = true
    refilter()

    local col = 2 + #query
    if vim.api.nvim_win_is_valid(win) then
      local ok, cur = pcall(vim.api.nvim_win_get_cursor, win)
      if ok and cur and cur[1] == 1 then col = math.max(2, cur[2]) end
    end

    local lines = { "> " .. query }
    local max_results = math.max(1, height - 2)
    local shown = 0
    for i, item in ipairs(filtered) do
      if shown >= max_results then break end
      local cur = i == cursor and ">" or " "
      table.insert(lines, string.format("%s %s", cur, item.text))
      shown = shown + 1
    end
    if #filtered == 0 then table.insert(lines, "  (no matches)") end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
      virt_lines = { { { "  <cr> confirm  <c-n>/<c-p> move  <esc> abort", "Comment" } } },
      virt_lines_above = false,
    })

    if vim.api.nvim_win_is_valid(win) then
      local max_col = 2 + #query
      pcall(vim.api.nvim_win_set_cursor, win, { 1, math.min(col, max_col) })
    end
    redrawing = false
  end

  local function sync_query_from_buf()
    if closed or redrawing then return end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local raw = lines[1] or ""
    if #lines > 1 then
      for i = 2, #lines do
        local l = lines[i]
        if l and not l:match("^[> ] ") and not l:match("^%s*%(no matches") then raw = raw .. l end
      end
    end
    local next_query = raw:gsub("^>%s?", ""):gsub("[\r\n]", "")
    if next_query ~= query then
      query = next_query
      cursor = 1
    end
    redraw()
  end

  local function do_select() finish(current()) end

  local function move(delta)
    if #filtered == 0 then return end
    cursor = math.max(1, math.min(cursor + delta, #filtered))
    redraw()
  end

  local map = function(modes, key, fn)
    vim.keymap.set(modes, key, fn, { buffer = bufnr, silent = true, noremap = true, nowait = true })
  end

  map({ "n", "i" }, "<cr>", function() vim.schedule(do_select) end)
  map({ "n", "i" }, "<c-c>", function() vim.schedule(abort) end)
  map({ "n", "i" }, "<esc>", function() vim.schedule(abort) end)
  map("n", "q", function() vim.schedule(abort) end)
  map({ "n", "i" }, "<c-n>", function() move(1) end)
  map({ "n", "i" }, "<down>", function() move(1) end)
  map({ "n", "i" }, "<c-p>", function() move(-1) end)
  map({ "n", "i" }, "<up>", function() move(-1) end)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = bufnr,
    callback = sync_query_from_buf,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      if closed or redrawing or not vim.api.nvim_win_is_valid(win) then return end
      local cur = vim.api.nvim_win_get_cursor(win)
      if cur[1] ~= 1 then
        local col = math.min(cur[2], 2 + #query)
        pcall(vim.api.nvim_win_set_cursor, win, { 1, math.max(2, col) })
      elseif cur[2] < 2 then
        pcall(vim.api.nvim_win_set_cursor, win, { 1, 2 })
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(win),
    once = true,
    callback = function()
      if not result_set then abort() end
    end,
  })

  redraw()
  local function reclaim()
    if closed then return end
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() ~= win then
      pcall(vim.api.nvim_set_current_win, win)
      local mode = vim.api.nvim_get_mode().mode
      if not mode:match("^[iR]") then pcall(vim.cmd, "startinsert") end
      pcall(vim.cmd, "redraw")
    end
  end
  reclaim()
  for _, delay in ipairs({ 10, 30, 60, 100 }) do
    vim.defer_fn(reclaim, delay)
  end
  vim.cmd("startinsert!")
end

return M
