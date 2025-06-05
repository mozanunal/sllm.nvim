-- lua/sllm/ui.lua
local M = {}
local Utils = require('sllm.utils')
local llm_buf = nil

-- Animation state
local animation_timer = nil
-- Braille spinner frames are often good for terminals
local animation_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local current_animation_frame_idx = 1
local loading_indicator_line_num = -1 -- Buffer line number (0-indexed) of the "Thinking..." text
local is_loading_active = false

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

local create_llm_win = function(window_type, model_name)
  local win_opts
  ensure_llm_buffer()
  window_type = window_type or 'vertical'
  if window_type == 'float' then
    win_opts = create_llm_float_win_opts()
  elseif window_type == 'horizontal' then
    win_opts = { split = 'below' }
  else
    win_opts = { split = 'right' }
  end
  local win_id = vim.api.nvim_open_win(llm_buf, false, win_opts)
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })
  vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
  vim.api.nvim_set_option_value('number', false, { win = win_id })

  local model_display = model_name and model_name or '(default)'
  local winbar_text = string.format('  sllm.nvim | Model: %s', model_display)
  vim.api.nvim_set_option_value('winbar', winbar_text, { win = win_id })

  return win_id
end

-- Helper to set a specific line in the buffer
local set_buffer_line = function(bufnr, lnum, text)
  if Utils.buf_is_valid(bufnr) and lnum >= 0 and lnum < vim.api.nvim_buf_line_count(bufnr) then
    vim.api.nvim_buf_set_lines(bufnr, lnum, lnum + 1, false, { text })
  end
end

M.start_loading_indicator = function()
  if is_loading_active then return end -- Don't start if already active

  ensure_llm_buffer()
  is_loading_active = true
  current_animation_frame_idx = 1

  local placeholder_text = animation_frames[current_animation_frame_idx] .. " Thinking..."
  -- Append an empty line then the placeholder. The indicator will be on the second new line.
  vim.api.nvim_buf_set_lines(llm_buf, -1, -1, false, { "", placeholder_text })
  loading_indicator_line_num = vim.api.nvim_buf_line_count(llm_buf) - 1 -- 0-indexed line number

  if animation_timer then animation_timer:close() end -- Close previous timer if any (defensive)
  animation_timer = vim.loop.new_timer()

  animation_timer:start(0, 150, vim.schedule_wrap(function()
    if not is_loading_active then -- Animation was stopped externally
      if animation_timer then
        animation_timer:stop()
        animation_timer:close()
        animation_timer = nil
      end
      return
    end

    if not Utils.buf_is_valid(llm_buf) or loading_indicator_line_num < 0
        or loading_indicator_line_num >= vim.api.nvim_buf_line_count(llm_buf) then
      -- Buffer state is unexpected (e.g., cleared, line deleted externally)
      M.stop_loading_indicator() -- Clean up
      return
    end

    current_animation_frame_idx = (current_animation_frame_idx % #animation_frames) + 1
    local new_text = animation_frames[current_animation_frame_idx] .. " Thinking..."
    set_buffer_line(llm_buf, loading_indicator_line_num, new_text)
  end))
end

M.stop_loading_indicator = function(replacement_lines)
  if not is_loading_active then return end

  is_loading_active = false -- Signal the timer callback to stop and prevent new starts
  if animation_timer then
    animation_timer:stop()
    animation_timer:close()
    animation_timer = nil
  end

  if Utils.buf_is_valid(llm_buf) and loading_indicator_line_num >= 0
      and loading_indicator_line_num < vim.api.nvim_buf_line_count(llm_buf) then
    -- The loading indicator was preceded by an empty line.
    -- So we operate on `loading_indicator_line_num - 1` and `loading_indicator_line_num`.
    local start_replace_line = loading_indicator_line_num - 1
    if start_replace_line < 0 then start_replace_line = 0 end -- Should not happen with current logic

    if replacement_lines then
      vim.api.nvim_buf_set_lines(llm_buf, start_replace_line, loading_indicator_line_num + 1, false, replacement_lines)
    else
      -- No replacement: delete the loading indicator and its preceding empty line
      vim.api.nvim_buf_set_lines(llm_buf, start_replace_line, loading_indicator_line_num + 1, false, {})
    end
  end
  loading_indicator_line_num = -1 -- Reset line number
end

M.clean_llm_buffer = function()
  if is_loading_active then
    M.stop_loading_indicator() -- Stop animation and clear its lines (using nil for replacement_lines)
  end
  if Utils.buf_is_valid(llm_buf) then
    vim.api.nvim_buf_set_lines(llm_buf, 0, -1, false, {})
  end
  -- loading_indicator_line_num is reset by stop_loading_indicator
end

M.show_llm_buffer = function(window_type, model_name)
  local win = Utils.check_buffer_visible(llm_buf)
  if win then return win end
  ensure_llm_buffer()
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
    ensure_llm_buffer()
    vim.api.nvim_buf_set_lines(llm_buf, -1, -1, false, lines)
    local llm_win = Utils.check_buffer_visible(llm_buf)
    if llm_win then
      local last_line = vim.api.nvim_buf_line_count(llm_buf)
      vim.api.nvim_win_set_cursor(llm_win, { last_line, 0 })
    end
  end
end

M.update_llm_win_title = function(model_name)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win and vim.api.nvim_win_is_valid(llm_win) then
    local model_display = model_name and model_name or '(default)'
    local winbar_text = string.format('  sllm.nvim | Model: %s', model_display)
    vim.api.nvim_set_option_value('winbar', winbar_text, { win = llm_win })
  end
end

return M
