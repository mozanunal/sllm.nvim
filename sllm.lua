local M = {}

-- Module vars
M.llm_buf = nil
M.llm_context = nil
M.continue = true

-- Private functions
local function buf_is_valid(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

local function find_llm_window()
  if not buf_is_valid(M.llm_buf) then return nil end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == M.llm_buf then return w end
  end
  return nil
end

local function get_llm_buffer()
  if not buf_is_valid(M.llm_buf) then
    -- Create new buffer
    M.llm_buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch buffer
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = M.llm_buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = M.llm_buf })
  end
  return M.llm_buf
end

local function append_to_llm_buffer(lines)
  if lines then
    vim.api.nvim_buf_set_lines(M.llm_buf, -1, -1, false, lines)
    -- Set the cursor to the last line of the buffer
    local win = find_llm_window() -- Find the window associated with the LLM buffer
    if win then
      local last_line = vim.api.nvim_buf_line_count(M.llm_buf)
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

    -- "wincmd p" jumps back to the previously active window
    vim.cmd('wincmd p')
  end
end

local function clean_llm_buffer()
  if buf_is_valid(M.llm_buf) then
    -- Replace all lines with an empty list, effectively clearing the buffer
    vim.api.nvim_buf_set_lines(M.llm_buf, 0, -1, false, {})
  end
end

-- Public functions
function M.new_chat()
  M.continue = false
  clean_llm_buffer()
  show_llm_buffer()
  append_to_llm_buffer({ 'New chat created.' })
  M.ask_llm()
  M.continue = true
end

-- Public function #1: focus the LLM window if it's open; otherwise show it.
function M.focus_llm_window()
  local llm_win = find_llm_window()
  if llm_win then
    vim.api.nvim_set_current_win(llm_win)
  else
    show_llm_buffer()
    local llm_win = find_llm_window()
    vim.api.nvim_set_current_win(llm_win)
  end
end

-- Public function #2: toggle the LLM buffer’s visibility.
function M.toggle_llm_buffer()
  local llm_win = find_llm_window()
  if llm_win then
    vim.api.nvim_win_close(llm_win, false)
  else
    show_llm_buffer()
  end
end

function M.add_current_file_to_context()
  -- Initialize M.llm_context if it's nil
  M.llm_context = M.llm_context or {}

  -- Get the filenam from the active buffer
  local filename = vim.api.nvim_buf_get_name(0)

  -- Also store the filename in M.llm_context
  table.insert(M.llm_context, filename)
  vim.notify('File added to LLM context: ' .. filename, vim.log.levels.INFO, { title = 'LLM Context' })
end

function M.reset_context()
  M.llm_context = nil -- Clear the context
  vim.notify('LLM context has been reset.', vim.log.levels.INFO, { title = 'LLM Context' })
end

-- Public function #3: prompt user for input, run `llm`, and stream output to the buffer.
function M.ask_llm()
  local user_input = vim.fn.input('Prompt: ')
  if user_input == '' then
    print('No prompt provided.')
    return
  end

  -- Show/focus the buffer so we see the conversation happen
  show_llm_buffer()

  -- Build the command
  local cmd = M.continue and 'llm -c ' or 'llm '
  if M.llm_context then
    for _, filename in ipairs(M.llm_context) do
      cmd = cmd .. '-f ' .. filename .. ' '
    end
  end
  cmd = cmd .. vim.fn.shellescape(user_input)

  -- Add prompt to buffer
  append_to_llm_buffer({ '## Prompt', '', user_input, '' })
  if M.llm_context then
    append_to_llm_buffer({ '## Context' })
    for _, filename in ipairs(M.llm_context) do
      append_to_llm_buffer({ '- ' .. filename })
    end
    append_to_llm_buffer({ '' })
  end
  append_to_llm_buffer({ '## Response', '' })

  -- Run `llm` asynchronously an d stream output to the buffer.
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    pty = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          -- Remove carriage returns
          line = line:gsub('\r', '')
          append_to_llm_buffer({ line })
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
      -- append_to_llm_buffer({ "---" })
    end,
  })
end

-- Public function #4: set up user commands and the keymaps you requested.
function M.setup()
  vim.keymap.set('n', '<leader>ss', M.ask_llm, { desc = 'Ask LLM' })
  vim.keymap.set('n', '<leader>sn', M.new_chat, { desc = 'New LLM chat' })
  vim.keymap.set('n', '<leader>sa', M.add_current_file_to_context, { desc = 'Add file to llm context' })
  vim.keymap.set('n', '<leader>sr', M.reset_context, { desc = 'Reset LLM context' }) -- Keymap for resetting context
  vim.keymap.set('n', '<leader>sf', M.focus_llm_window, { desc = 'Focus LLM window' })
  vim.keymap.set('n', '<leader>st', M.toggle_llm_buffer, { desc = 'Toggle LLM buffer visibility' })
end

M.setup()
_G.M = M
