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

local create_llm_win = function()
  -- Create a vertical split. Neovim automatically moves you into this new window.
  vim.cmd('vsplit')
  -- Put the LLM buffer in the newly created window.
  vim.api.nvim_win_set_buf(0, llm_buf)

  -- Optional window-local settings
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_option_value('wrap', true, { win = new_win })
  vim.api.nvim_set_option_value('linebreak', true, { win = new_win })
  vim.api.nvim_set_option_value('number', false, { win = new_win })
  vim.api.nvim_set_option_value('winbar', '  sllm.nvim', { win = new_win })
  vim.cmd('wincmd p')
  return new_win
end

M.clean_llm_buffer = function()
  if Utils.buf_is_valid(llm_buf) then
    -- Replace all lines with an empty list, effectively clearing the buffer
    vim.api.nvim_buf_set_lines(llm_buf, 0, -1, false, {})
  end
end

M.show_llm_buffer = function()
  local win = Utils.check_buffer_visible(llm_buf)
  if win then return win end
  ensure_llm_buffer()
  create_llm_win()
end

M.focus_llm_buffer = function()
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win then
    vim.api.nvim_set_current_win(llm_win)
  else
    llm_win = M.show_llm_buffer()
    vim.api.nvim_set_current_win(llm_win)
  end
end

M.toggle_llm_buffer = function()
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win then
    vim.api.nvim_win_close(llm_win, false)
  else
    M.show_llm_buffer()
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
