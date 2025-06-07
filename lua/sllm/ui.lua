local M = {}
local Utils = require('sllm.utils')
local llm_buf = nil

-- Animation state
local animation_timer = nil
-- Braille spinner frames are often good for terminals
local animation_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local current_animation_frame_idx = 1
local is_loading_active = false
local original_winbar_text = ''

--- Ensures the llm buffer exists and returns its handle.
--- Never returns nil.
---@return integer bufnr
local ensure_llm_buffer = function()
  if llm_buf and Utils.buf_is_valid(llm_buf) then
    return llm_buf
  else
    llm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = llm_buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = llm_buf })
    vim.api.nvim_buf_set_name(llm_buf, 'sllm://chat')
    return llm_buf
  end
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

-- Helper to update the winbar of the llm window if it exists.
local update_winbar = function(text)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win and vim.api.nvim_win_is_valid(llm_win) then
    vim.api.nvim_set_option_value('winbar', text, { win = llm_win })
  end
end

local create_llm_win = function(window_type, model_name)
  local win_opts
  local valid_llm_buf = ensure_llm_buffer()
  window_type = window_type or 'vertical'
  if window_type == 'float' then
    win_opts = create_llm_float_win_opts()
  elseif window_type == 'horizontal' then
    win_opts = { split = 'below' }
  else
    win_opts = { split = 'right' }
  end
  local win_id = vim.api.nvim_open_win(valid_llm_buf, false, win_opts)
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })
  vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
  vim.api.nvim_set_option_value('number', false, { win = win_id })

  M.update_llm_win_title(model_name)

  return win_id
end

M.start_loading_indicator = function()
  if is_loading_active then return end

  local llm_win = Utils.check_buffer_visible(llm_buf)
  if not (llm_win and vim.api.nvim_win_is_valid(llm_win)) then return end

  is_loading_active = true
  current_animation_frame_idx = 1

  -- Store the current winbar text to restore it later
  original_winbar_text = vim.api.nvim_get_option_value('winbar', { win = llm_win })

  if animation_timer then animation_timer:close() end -- Defensive
  animation_timer = vim.loop.new_timer()

  animation_timer:start(
    0,
    150,
    vim.schedule_wrap(function()
      if not is_loading_active then -- Animation was stopped externally
        if animation_timer then
          animation_timer:stop()
          animation_timer:close()
          animation_timer = nil
        end
        return
      end

      local llm_win_check = Utils.check_buffer_visible(llm_buf)
      if not (llm_win_check and vim.api.nvim_win_is_valid(llm_win_check)) then
        -- Window was closed during animation
        M.stop_loading_indicator() -- Clean up
        return
      end

      current_animation_frame_idx = (current_animation_frame_idx % #animation_frames) + 1
      local frame = animation_frames[current_animation_frame_idx]
      local new_winbar_text = string.format('%s %s', frame, original_winbar_text)
      update_winbar(new_winbar_text)
    end)
  )
end

M.stop_loading_indicator = function()
  if not is_loading_active then return end

  is_loading_active = false -- Signal the timer callback to stop
  if animation_timer then
    animation_timer:stop()
    animation_timer:close()
    animation_timer = nil
  end

  -- Restore the original winbar text
  if original_winbar_text ~= '' then update_winbar(original_winbar_text) end
  original_winbar_text = '' -- Clear the stored text
end

M.clean_llm_buffer = function()
  if is_loading_active then
    M.stop_loading_indicator() -- Stop animation and restore the original title
  end
  if llm_buf then
    if Utils.buf_is_valid(llm_buf) then vim.api.nvim_buf_set_lines(llm_buf, 0, -1, false, {}) end
  end
end

M.show_llm_buffer = function(window_type, model_name)
  local win = Utils.check_buffer_visible(llm_buf)
  if win then return win end
  -- Buffer doesn't exist or isn't in a window, create it.
  return create_llm_win(window_type, model_name)
end

M.focus_llm_buffer = function(window_type, model_name)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if window_type == 'float' and llm_win and vim.api.nvim_win_is_valid(llm_win) then
    vim.api.nvim_set_current_win(llm_win)
  elseif llm_win then
    vim.api.nvim_set_current_win(llm_win)
  else
    llm_win = M.show_llm_buffer(window_type, model_name)
    vim.api.nvim_set_current_win(llm_win)
  end
end

M.toggle_llm_buffer = function(window_type, model_name)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win then
    vim.api.nvim_win_close(llm_win, false)
  else
    M.show_llm_buffer(window_type, model_name)
  end
end

M.append_to_llm_buffer = function(lines)
  if lines then
    local valid_llm_buf = ensure_llm_buffer()
    vim.api.nvim_buf_set_lines(valid_llm_buf, -1, -1, false, lines)
    local llm_win = Utils.check_buffer_visible(valid_llm_buf)
    if llm_win then
      local last_line = vim.api.nvim_buf_line_count(valid_llm_buf)
      vim.api.nvim_win_set_cursor(llm_win, { last_line, 0 })
    end
  end
end

M.update_llm_win_title = function(model_name)
  local model_display = model_name and model_name or '(default)'
  local winbar_text = string.format('  sllm.nvim | Model: %s', model_display)

  if is_loading_active then
    -- Animation is running, so we update the text that will be restored later.
    original_winbar_text = winbar_text
  else
    -- Not loading, so we can update the winbar directly.
    update_winbar(winbar_text)
  end
end

return M
