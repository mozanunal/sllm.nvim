---@module "sllm.ui"
-- Module definition ==========================================================
local UI = {}
local H = {}

-- Helper data ================================================================
H.utils = require('sllm.utils')

---@type integer?  -- Buffer handle for LLM content
H.llm_buf = nil

---@type uv_timer_t?  -- Animation timer (from `vim.loop.new_timer()`)
H.animation_timer = nil

---@type string[]  -- Braille spinner frames
H.animation_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

---@type integer  -- Current index into `H.animation_frames`
H.current_animation_frame_idx = 1

---@type boolean  -- Whether loading animation is active
H.is_loading_active = false

---@type string  -- Winbar text to restore after animation
H.original_winbar_text = ''

--- Ensure the LLM buffer exists (hidden, markdown) and return its handle.
---@return integer bufnr  Always‐valid buffer handle.
H.ensure_llm_buffer = function()
  if H.llm_buf and H.utils.buf_is_valid(H.llm_buf) then
    return H.llm_buf
  else
    H.llm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = H.llm_buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = H.llm_buf })
    vim.api.nvim_buf_set_name(H.llm_buf, 'sllm://chat')
    return H.llm_buf
  end
end

--- Compute centered floating‐window options for the LLM buffer.
---@return table<string, number|string>  Options suitable for `nvim_open_win`.
H.create_llm_float_win_opts = function()
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
H.update_winbar = function(text)
  local llm_win = H.utils.check_buffer_visible(H.llm_buf)
  if llm_win and vim.api.nvim_win_is_valid(llm_win) then
    vim.api.nvim_set_option_value('winbar', text, { win = llm_win })
  end
end

--- Create and configure a window for the LLM buffer.
---@param window_type? string  "float" | "horizontal" | "vertical"  Default: "vertical".
---@param model_name?  string  Model name for the title.
---@param online_enabled? boolean  Whether online mode is enabled.
---@return integer win_id      Window handle.
H.create_llm_win = function(window_type, model_name, online_enabled)
  window_type = window_type or 'vertical'
  local buf = H.ensure_llm_buffer()

  -- choose window options based on type
  local win_opts
  if window_type == 'float' then
    win_opts = H.create_llm_float_win_opts()
  elseif window_type == 'horizontal' then
    win_opts = { split = 'below' }
  else
    win_opts = { split = 'right' }
  end

  local win_id = vim.api.nvim_open_win(buf, false, win_opts)
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })
  vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
  vim.api.nvim_set_option_value('number', false, { win = win_id })

  UI.update_llm_win_title(model_name, online_enabled)
  return win_id
end

--- Start the Braille spinner in the LLM window's winbar.
---@return nil
-- Public API =================================================================
function UI.start_loading_indicator()
  if H.is_loading_active then return end
  local llm_win = H.utils.check_buffer_visible(H.llm_buf)
  if not (llm_win and vim.api.nvim_win_is_valid(llm_win)) then return end

  H.is_loading_active = true
  H.current_animation_frame_idx = 1
  H.original_winbar_text = vim.api.nvim_get_option_value('winbar', { win = llm_win })

  if H.animation_timer then
    H.animation_timer:close()
    H.animation_timer = nil
  end
  H.animation_timer = vim.loop.new_timer()
  H.animation_timer:start(
    0,
    150,
    vim.schedule_wrap(function()
      if not H.is_loading_active then
        H.animation_timer:stop()
        H.animation_timer:close()
        H.animation_timer = nil
        return
      end

      local win_check = H.utils.check_buffer_visible(H.llm_buf)
      if not (win_check and vim.api.nvim_win_is_valid(win_check)) then
        UI.stop_loading_indicator()
        return
      end

      H.current_animation_frame_idx = (H.current_animation_frame_idx % #H.animation_frames) + 1
      local frame = H.animation_frames[H.current_animation_frame_idx]
      H.update_winbar(string.format('%s %s', frame, H.original_winbar_text))
    end)
  )
end

--- Stop the loading spinner and restore the original winbar text.
---@return nil
function UI.stop_loading_indicator()
  if not H.is_loading_active then return end
  H.is_loading_active = false
  if H.animation_timer then
    H.animation_timer:stop()
    H.animation_timer:close()
    H.animation_timer = nil
  end
  if H.original_winbar_text ~= '' then H.update_winbar(H.original_winbar_text) end
  H.original_winbar_text = ''
end

--- Clear the LLM buffer and stop any active loading animation.
---@return nil
function UI.clean_llm_buffer()
  if H.is_loading_active then UI.stop_loading_indicator() end
  if H.llm_buf and H.utils.buf_is_valid(H.llm_buf) then vim.api.nvim_buf_set_lines(H.llm_buf, 0, -1, false, {}) end
end

--- Show the LLM buffer, creating a window if needed.
---@param window_type? string  `"float"|"horizontal"|"vertical"`.
---@param model_name?  string  Model name for the title.
---@param online_enabled? boolean  Whether online mode is enabled.
---@return integer win_id  Window handle where the buffer is shown.
function UI.show_llm_buffer(window_type, model_name, online_enabled)
  local win = H.utils.check_buffer_visible(H.llm_buf)
  if win then
    return win
  else
    return H.create_llm_win(window_type, model_name, online_enabled)
  end
end

--- Focus (enter) the LLM window, creating it if necessary.
---@param window_type? string  `"float"|"horizontal"|"vertical"`.
---@param model_name?  string  Model name for the title.
---@param online_enabled? boolean  Whether online mode is enabled.
---@return nil
function UI.focus_llm_buffer(window_type, model_name, online_enabled)
  local win = H.utils.check_buffer_visible(H.llm_buf)
  if win then
    vim.api.nvim_set_current_win(win)
  else
    win = UI.show_llm_buffer(window_type, model_name, online_enabled)
    vim.api.nvim_set_current_win(win)
  end
end

--- Toggle the LLM window: close if open, open if closed.
---@param window_type? string  `"float"|"horizontal"|"vertical"`.
---@param model_name?  string  Model name for the title.
---@param online_enabled? boolean  Whether online mode is enabled.
---@return nil
function UI.toggle_llm_buffer(window_type, model_name, online_enabled)
  local win = H.utils.check_buffer_visible(H.llm_buf)
  if win then
    vim.api.nvim_win_close(win, false)
  else
    UI.show_llm_buffer(window_type, model_name, online_enabled)
  end
end

--- Append lines to the end of the LLM buffer and scroll to bottom.
---@param lines string[]  Lines to append.
---@param scroll_to_bottom boolean  Whether or not to scroll to the bottom of the buffer
---@return nil
function UI.append_to_llm_buffer(lines, scroll_to_bottom)
  if not lines then return end
  local buf = H.ensure_llm_buffer()
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  local win = H.utils.check_buffer_visible(buf)
  if win and scroll_to_bottom then
    local last = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { last, 0 })
  end
end

--- Update the LLM window's title (winbar) with the given model name.
---@param model_name? string  Name of the model, or `nil` for default.
---@param online_enabled? boolean  Whether online mode is enabled.
---@return nil
function UI.update_llm_win_title(model_name, online_enabled)
  local display = model_name or '(default)'
  local online_indicator = online_enabled and ' 🌐' or ''
  local title = string.format('  sllm.nvim | Model: %s%s', display, online_indicator)
  if H.is_loading_active then
    H.original_winbar_text = title
  else
    H.update_winbar(title)
  end
end

--- Update the winbar to show accumulated session statistics.
---@param stats table  Table with `input`, `output`, and `cost` fields.
---@return nil
function UI.update_session_stats(stats)
  local llm_win = H.utils.check_buffer_visible(H.llm_buf)
  if not (llm_win and vim.api.nvim_win_is_valid(llm_win)) then return end

  -- Get current winbar and strip any existing stats
  local current_winbar = vim.api.nvim_get_option_value('winbar', { win = llm_win })
  -- Remove any existing stats section (everything after " | 📊")
  local base_winbar = current_winbar:match('^(.-)%s*|%s*📊') or current_winbar

  -- Format stats: in/out tokens and cost
  local stats_text = string.format(' | 📊 In: %d Out: %d Cost: $%.6f', stats.input, stats.output, stats.cost)

  -- Append stats to base winbar
  local new_winbar = base_winbar .. stats_text

  if H.is_loading_active then
    H.original_winbar_text = new_winbar
  else
    H.update_winbar(new_winbar)
  end
end

--- Copy the first code block from the LLM buffer to the clipboard.
---@return boolean  `true` if a code block was found and copied; `false` otherwise.
function UI.copy_first_code_block()
  local buf = H.ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code_blocks = H.utils.extract_code_blocks(lines)

  if #code_blocks == 0 then return false end

  vim.fn.setreg('+', code_blocks[1])
  vim.fn.setreg('"', code_blocks[1])
  return true
end

--- Copy the last code block from the LLM buffer to the clipboard.
---@return boolean  `true` if a code block was found and copied; `false` otherwise.
function UI.copy_last_code_block()
  local buf = H.ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code_blocks = H.utils.extract_code_blocks(lines)

  if #code_blocks == 0 then return false end

  vim.fn.setreg('+', code_blocks[#code_blocks])
  vim.fn.setreg('"', code_blocks[#code_blocks])
  return true
end

--- Copy the last response from the LLM buffer to the clipboard.
--- Extracts content from the last response marker to the end.
---@param response_header? string  The response header to search for (default: '> 🤖 Response').
---@return boolean  `true` if content was copied; `false` if no response found.
function UI.copy_last_response(response_header)
  response_header = response_header or '> 🤖 Response'
  local buf = H.ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  if #lines == 0 then return false end

  -- Find the last occurrence of the response marker
  local last_response_idx = nil
  for i = #lines, 1, -1 do
    if lines[i]:match('^' .. vim.pesc(response_header)) then
      last_response_idx = i
      break
    end
  end

  if not last_response_idx then return false end

  -- Extract from the response marker to the end (skip the marker line and empty lines)
  local response_lines = {}
  for i = last_response_idx + 1, #lines do
    table.insert(response_lines, lines[i])
  end

  -- Remove leading empty lines
  while #response_lines > 0 and response_lines[1]:match('^%s*$') do
    table.remove(response_lines, 1)
  end

  -- Remove trailing empty lines
  while #response_lines > 0 and response_lines[#response_lines]:match('^%s*$') do
    table.remove(response_lines)
  end

  if #response_lines == 0 then return false end

  local content = table.concat(response_lines, '\n')
  vim.fn.setreg('+', content)
  vim.fn.setreg('"', content)
  return true
end

return UI
