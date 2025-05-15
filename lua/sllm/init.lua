local M = {}

-- Public vars
M.selected_model = nil
M.continue = true
M.show_usage = false

-- Private vars
local llm_buf = nil
local llm_context = nil
local llm_job_id = nil
local cwd = vim.fn.getcwd()

-- local notify_func = vim.notify
local notify_func = require('mini.notify').make_notify()
-- local pick_func = vim.ui.select
local pick_func = require("mini.pick").ui_select

-- Private functions
local function buf_is_valid(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

local function find_llm_window()
  if not buf_is_valid(llm_buf) then return nil end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == llm_buf then return w end
  end
  return nil
end

local function get_llm_buffer()
  if not buf_is_valid(llm_buf) then
    -- Create new buffer
    llm_buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch buffer
    vim.bo[llm_buf].bufhidden = 'hide'
    vim.bo[llm_buf].filetype = 'markdown'
  end
  return llm_buf
end

local function append_to_llm_buffer(lines)
  if lines then
    vim.api.nvim_buf_set_lines(llm_buf, -1, -1, false, lines)
    -- Set the cursor to the last line of the buffer
    local win = find_llm_window() -- Find the window associated with the LLM buffer
    if win then
      local last_line = vim.api.nvim_buf_line_count(llm_buf)
      vim.api.nvim_win_set_cursor(win, { last_line, 0 }) -- Move cursor to the last line in the window
    end
  end
end

local function show_llm_buffer()
  local buf = get_llm_buffer()
  local win = find_llm_window()
  -- If the LLM buffer isn't visible, open it in a new vertical split.
  if not win then
    -- Create a vertical split. Neovim automatically moves you into this new window.
    vim.cmd('vsplit')
    -- Put the LLM buffer in the newly created window.
    vim.api.nvim_win_set_buf(0, buf)

    -- Optional window-local settings
    local new_win = vim.api.nvim_get_current_win()
    vim.wo[new_win].wrap = true
    vim.wo[new_win].linebreak = true
    vim.wo[new_win].number = false
    vim.wo[new_win].winbar = "  sllm.nvim"
    vim.cmd('wincmd p')
  end
end

local function clean_llm_buffer()
  if buf_is_valid(llm_buf) then
    -- Replace all lines with an empty list, effectively clearing the buffer
    vim.api.nvim_buf_set_lines(llm_buf, 0, -1, false, {})
  end
end

local function in_visual_mode()
  local current_mode = vim.api.nvim_get_mode().mode
  return current_mode:match('^[vV]$') ~= nil
end

-- Function to get the current visual selection
local function get_visual_selection()
  -- Check if there is a visual selection
  if in_visual_mode() then
    local _, ls, cs = unpack(vim.fn.getpos('v'))
    local _, le, ce = unpack(vim.fn.getpos('.'))
    return vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
  end
  return nil -- No selection
end

-- Public functions
function M.new_chat()
  M.continue = false
  clean_llm_buffer()
  show_llm_buffer()
  notify_func('[sllm] new chat created', vim.log.levels.INFO)
  M.ask_llm()
  M.continue = true
end

-- focus the LLM window if it's open; otherwise show it.
function M.focus_llm_window()
  local llm_win = find_llm_window()
  if llm_win then
    vim.api.nvim_set_current_win(llm_win)
  else
    show_llm_buffer()
    llm_win = find_llm_window()
    vim.api.nvim_set_current_win(llm_win)
  end
end

-- toggle the LLM buffer’s visibility.
function M.toggle_llm_buffer()
  local llm_win = find_llm_window()
  if llm_win then
    vim.api.nvim_win_close(llm_win, false)
  else
    show_llm_buffer()
  end
end

function M.add_current_file_to_context()
  -- Initialize llm_context if it's nil
  llm_context = llm_context or {}

  -- Get the filenam from the active buffer
  local abspath = vim.api.nvim_buf_get_name(0)
  local relpath = vim.fs.relpath(cwd, abspath)
  local context_path = nil
  if relpath then
    context_path = relpath
  else
    context_path = abspath
  end

  -- Check if the file is already in the context
  local is_in_context = vim.tbl_contains(llm_context, context_path)
  if not is_in_context then
    table.insert(llm_context, context_path)
    -- Also store the filename in llm_context
    notify_func('[sllm] context + ' .. context_path, vim.log.levels.INFO)
  else
    notify_func('[sllm] file already in context: ' .. context_path, vim.log.levels.WARN)
  end
end

function M.reset_context()
  llm_context = nil -- Clear the context
  notify_func('[sllm] context reset.', vim.log.levels.INFO)
end

function M.cancel()
  if llm_job_id then
    vim.fn.jobstop(llm_job_id)
    notify_func('[sllm] canceled ❌', vim.log.levels.WARN)
    llm_job_id = nil
  else
    notify_func('[sllm] no active llm job', vim.log.levels.INFO)
  end
end

-- prompt user for input, run `llm`, and stream output to the buffer.
function M.ask_llm()
  local visual_selection = get_visual_selection()
  local user_input = vim.fn.input('Prompt: ')
  if user_input == '' then
    notify_func('[sllm] no prompt provided.', vim.log.levels.INFO)
    return
  end

  if visual_selection then
    user_input = user_input .. '\nSelection: \n```' .. table.concat(visual_selection, '\n') .. '```\n'
  end

  -- Show/focus the buffer so we see the conversation happen
  show_llm_buffer()

  -- Build the command
  local cmd = M.continue and 'llm -c ' or 'llm '
  if M.show_usage then cmd = cmd .. '-u ' end
  if M.selected_model then cmd = cmd .. '-m ' .. M.selected_model .. ' ' end
  if llm_context then
    for _, filename in ipairs(llm_context) do
      cmd = cmd .. '-f ' .. filename .. ' '
    end
  end
  cmd = cmd .. vim.fn.shellescape(user_input)

  -- Add prompt to buffer
  local lines = vim.split(user_input, '\n', { plain = true })
  append_to_llm_buffer({ '## Prompt', '' })
  append_to_llm_buffer(lines)
  append_to_llm_buffer({ '' })
  if llm_context then
    append_to_llm_buffer({ '## Context' })
    for _, filename in ipairs(llm_context) do
      append_to_llm_buffer({ '- ' .. filename })
    end
    append_to_llm_buffer({ '' })
  end
  append_to_llm_buffer({ '## Response', '' })

  -- Prevent multiple LLM jobs running at once:
  if llm_job_id then
    notify_func('[sllm] already running, please wait.', vim.log.levels.WARN)
    return
  end
  -- Run `llm` asynchronously an d stream output to the buffer.
  -- somewhere at the top of your module/file
  local stdout_acc = ''
  notify_func('[sllm] thinking...🤔', vim.log.levels.INFO)

  llm_job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    pty = true,
    on_stdout = function(_, data, _)
      if not data then return end

      for _, chunk in ipairs(data) do
        if chunk ~= '' then
          -- 1) accumulate everything
          stdout_acc = stdout_acc .. chunk

          -- 2) as long as there's a '\r' in the buffer, split & flush
          local cr_pos = stdout_acc:find('\r', 1, true)
          while cr_pos do
            -- the text up to (but not including) the '\r'
            local line = stdout_acc:sub(1, cr_pos - 1)
            append_to_llm_buffer({ line })

            -- drop the flushed part + the '\r' itself
            stdout_acc = stdout_acc:sub(cr_pos + 1)

            -- look for another '\r'
            cr_pos = stdout_acc:find('\r', 1, true)
          end
        end
      end
    end,

    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          append_to_llm_buffer({ line })
        end
      end
    end,

    on_exit = function(_, exit_code, _)
      -- if there’s leftover text without a trailing '\r', you can flush it here:
      if stdout_acc ~= '' then
        append_to_llm_buffer({ stdout_acc })
        stdout_acc = ''
      end
      append_to_llm_buffer({ "" })
      llm_job_id = nil
      notify_func('[sllm] done ✅', vim.log.levels.INFO)
      -- maybe log exit_code or append a separator...
    end,
  })
end

function M.check()
  -- Use the `vim.health` API provided by Neovim
  local health = require('vim.health')

  -- 1. Check for Neovim version
  local nvim_version = vim.version()
  if (nvim_version.major < 0) or (nvim_version.minor < 5) then
    health.warn('Neovim 0.5 or above is recommended for myplugin.')
  else
    health.ok('Neovim version is 0.5 or above.')
  end

  -- 2. Check if a required dependency exists
  local has_required_dep = vim.fn.executable('llm') == 1
  if not has_required_dep then
    health.error('llm is required by myplugin but not found in your PATH.')
  else
    health.ok('llm is installed and found in your PATH.')
  end
end

local function extract_models()
  local models = vim.fn.systemlist('llm models')
  local only_models = {}
  for _, line in ipairs(models) do
    local model = line:match('^.-:%s*([^(%s]+)')
    if model then table.insert(only_models, model) end
  end
  return only_models
end

function M.select_model()
  local models = extract_models()
  if not (models and #models > 0) then
    notify_func('[sllm] no models found.', vim.log.levels.ERROR)
    return
  end

  pick_func(models, {}, function(item)
    if item then
      M.selected_model = item
      notify_func('[sllm] selected model: ' .. item, vim.log.levels.INFO)
    else
      notify_func('[sllm] llm model not changed', vim.log.levels.WARN)
    end
  end)
end

-- set up user commands and the keymaps you requested.
function M.setup()
  M.show_usage = true
  vim.keymap.set('n', '<leader>ss', M.ask_llm, { desc = 'Ask LLM' })
  vim.keymap.set('v', '<leader>ss', M.ask_llm, { desc = 'Ask LLM' })
  vim.keymap.set('n', '<leader>sn', M.new_chat, { desc = 'New LLM chat' })
  vim.keymap.set('n', '<leader>sc', M.cancel, { desc = 'Cancel LLM request' })
  vim.keymap.set('n', '<leader>sa', M.add_current_file_to_context, { desc = 'Add file to llm context' })
  vim.keymap.set('n', '<leader>sr', M.reset_context, { desc = 'Reset LLM context' })
  vim.keymap.set('n', '<leader>sf', M.focus_llm_window, { desc = 'Focus LLM window' })
  vim.keymap.set('n', '<leader>st', M.toggle_llm_buffer, { desc = 'Toggle LLM buffer visibility' })
  vim.keymap.set('n', '<leader>sm', M.select_model, { desc = 'Select LLM model' })
end

return M
