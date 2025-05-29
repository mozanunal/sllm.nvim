local M = {}
local Utils = require('sllm.utils')
local llm_buf = nil

local ensure_llm_buffer = function()
  if not Utils.buf_is_valid(llm_buf) then
    llm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = llm_buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = llm_buf })
  end
  return llm_buf
end

local create_llm_float_win_opts = function()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.7)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local opts = {
    relative = 'editor',
    row = row > 0 and row or 0,
    col = col > 0 and col or 0,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    zindex = 50,
  }
  return opts
end

local create_llm_win = function(window_type)
  local win_opts = nil
  ensure_llm_buffer()
  window_type = window_type or 'vertical'
  if window_type == 'float' then
    win_opts = create_llm_float_win_opts()
  elseif window_type == 'horizontal' then
    win_opts = { split = "below" }
  else
    win_opts = { split = "right" }
  end
  local win_id = vim.api.nvim_open_win(llm_buf, false, win_opts)
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })
  vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
  vim.api.nvim_set_option_value('number', false, { win = win_id })
  vim.api.nvim_set_option_value('winbar', '  sllm.nvim', { win = win_id })
  return win_id
end

M.clean_llm_buffer = function()
  if Utils.buf_is_valid(llm_buf) then
    -- Replace all lines with an empty list, effectively clearing the buffer
    vim.api.nvim_buf_set_lines(llm_buf, 0, -1, false, {})
  end
end

M.show_llm_buffer = function(window_type)
  local win = Utils.check_buffer_visible(llm_buf)
  if win then return win end
  ensure_llm_buffer()
  return create_llm_win(window_type)
end

M.focus_llm_buffer = function(window_type)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if window_type == 'float' and floating_win_id and vim.api.nvim_win_is_valid(floating_win_id) then
    vim.api.nvim_set_current_win(floating_win_id)
  elseif llm_win then
    vim.api.nvim_set_current_win(llm_win)
  else
    llm_win = M.show_llm_buffer(window_type)
    vim.api.nvim_set_current_win(llm_win)
  end
end

M.toggle_llm_buffer = function(window_type)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win then
    vim.api.nvim_win_close(llm_win, false)
  else
    M.show_llm_buffer(window_type)
  end
end

M.append_to_llm_buffer = function(lines)
  if lines then
    vim.api.nvim_buf_set_lines(llm_buf, -1, -1, false, lines)
    local llm_win = Utils.check_buffer_visible(llm_buf)
    if llm_win then
      local last_line = vim.api.nvim_buf_line_count(llm_buf)
      vim.api.nvim_win_set_cursor(llm_win, { last_line, 0 }) -- Move cursor to the last line in the window
    end
  end
end

return M
