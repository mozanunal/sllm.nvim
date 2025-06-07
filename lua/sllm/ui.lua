---@module "sllm.ui"
local M = {}
local Utils = require('sllm.utils')

---@type integer?  -- Buffer handle for LLM content
local llm_buf = nil

---@type uv_timer_t?  -- Animation timer (from `vim.loop.new_timer()`)
local animation_timer = nil

---@type string[]  -- Braille spinner frames
local animation_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

---@type integer  -- Current index into `animation_frames`
local current_animation_frame_idx = 1

---@type boolean  -- Whether loading animation is active
local is_loading_active = false

---@type string  -- Winbar text to restore after animation
local original_winbar_text = ''

--- Ensure the LLM buffer exists (hidden, markdown) and return its handle.
---@return integer bufnr  Always‐valid buffer handle.
local function ensure_llm_buffer()
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

--- Compute centered floating‐window options for the LLM buffer.
---@return table<string, number|string>  Options suitable for `nvim_open_win`.
local function create_llm_float_win_opts()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.7)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return {
    relative = 'editor',
    row = row > 0 and row or 0,
    col = col > 0 and col or 0,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    zindex = 50,
  }
end

--- Update the winbar of the LLM window if it is visible.
---@param text string  New winbar text.
local function update_winbar(text)
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if llm_win and vim.api.nvim_win_is_valid(llm_win) then
    vim.api.nvim_set_option_value('winbar', text, { win = llm_win })
  end
end

--- Create and configure a window for the LLM buffer.
---@param window_type? string  "float" | "horizontal" | "vertical"  Default: "vertical".
---@param model_name?  string  Model name for the title.
---@return integer win_id      Window handle.
local function create_llm_win(window_type, model_name)
  window_type = window_type or 'vertical'
  local buf = ensure_llm_buffer()

  -- choose window options based on type
  local win_opts
  if window_type == 'float' then
    win_opts = create_llm_float_win_opts()
  elseif window_type == 'horizontal' then
    win_opts = { split = 'below' }
  else
    win_opts = { split = 'right' }
  end

  local win_id = vim.api.nvim_open_win(buf, false, win_opts)
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })
  vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
  vim.api.nvim_set_option_value('number', false, { win = win_id })

  M.update_llm_win_title(model_name)
  return win_id
end

--- Start the Braille spinner in the LLM window's winbar.
---@return nil
function M.start_loading_indicator()
  if is_loading_active then return end
  local llm_win = Utils.check_buffer_visible(llm_buf)
  if not (llm_win and vim.api.nvim_win_is_valid(llm_win)) then return end

  is_loading_active = true
  current_animation_frame_idx = 1
  original_winbar_text = vim.api.nvim_get_option_value('winbar', { win = llm_win })

  if animation_timer then
    animation_timer:close()
    animation_timer = nil
  end
  animation_timer = vim.loop.new_timer()
  animation_timer:start(
    0,
    150,
    vim.schedule_wrap(function()
      if not is_loading_active then
        animation_timer:stop()
        animation_timer:close()
        animation_timer = nil
        return
      end

      local win_check = Utils.check_buffer_visible(llm_buf)
      if not (win_check and vim.api.nvim_win_is_valid(win_check)) then
        M.stop_loading_indicator()
        return
      end

      current_animation_frame_idx = (current_animation_frame_idx % #animation_frames) + 1
      local frame = animation_frames[current_animation_frame_idx]
      update_winbar(string.format('%s %s', frame, original_winbar_text))
    end)
  )
end

--- Stop the loading spinner and restore the original winbar text.
---@return nil
function M.stop_loading_indicator()
  if not is_loading_active then return end
  is_loading_active = false
  if animation_timer then
    animation_timer:stop()
    animation_timer:close()
    animation_timer = nil
  end
  if original_winbar_text ~= '' then update_winbar(original_winbar_text) end
  original_winbar_text = ''
end

--- Clear the LLM buffer and stop any active loading animation.
---@return nil
function M.clean_llm_buffer()
  if is_loading_active then M.stop_loading_indicator() end
  if llm_buf and Utils.buf_is_valid(llm_buf) then vim.api.nvim_buf_set_lines(llm_buf, 0, -1, false, {}) end
end

--- Show the LLM buffer, creating a window if needed.
---@param window_type? string  `"float"|"horizontal"|"vertical"`.
---@param model_name?  string  Model name for the title.
---@return integer win_id  Window handle where the buffer is shown.
function M.show_llm_buffer(window_type, model_name)
  local win = Utils.check_buffer_visible(llm_buf)
  if win then
    return win
  else
    return create_llm_win(window_type, model_name)
  end
end

--- Focus (enter) the LLM window, creating it if necessary.
---@param window_type? string  `"float"|"horizontal"|"vertical"`.
---@param model_name?  string  Model name for the title.
---@return nil
function M.focus_llm_buffer(window_type, model_name)
  local win = Utils.check_buffer_visible(llm_buf)
  if win then
    vim.api.nvim_set_current_win(win)
  else
    win = M.show_llm_buffer(window_type, model_name)
    vim.api.nvim_set_current_win(win)
  end
end

--- Toggle the LLM window: close if open, open if closed.
---@param window_type? string  `"float"|"horizontal"|"vertical"`.
---@param model_name?  string  Model name for the title.
---@return nil
function M.toggle_llm_buffer(window_type, model_name)
  local win = Utils.check_buffer_visible(llm_buf)
  if win then
    vim.api.nvim_win_close(win, false)
  else
    M.show_llm_buffer(window_type, model_name)
  end
end

--- Append lines to the end of the LLM buffer and scroll to bottom.
---@param lines string[]  Lines to append.
---@return nil
function M.append_to_llm_buffer(lines)
  if not lines then return end
  local buf = ensure_llm_buffer()
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  local win = Utils.check_buffer_visible(buf)
  if win then
    local last = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { last, 0 })
  end
end

--- Update the LLM window's title (winbar) with the given model name.
---@param model_name? string  Name of the model, or `nil` for default.
---@return nil
function M.update_llm_win_title(model_name)
  local display = model_name or '(default)'
  local title = string.format('  sllm.nvim | Model: %s', display)
  if is_loading_active then
    original_winbar_text = title
  else
    update_winbar(title)
  end
end

return M
