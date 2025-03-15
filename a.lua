-- Create a new scratch buffer (unlisted, scratch buffer)
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

-- Open the buffer in a vertical split window
vim.cmd('vsplit')
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)

-- Function to append lines to the buffer
local function append_to_buf(lines)
  if lines then
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  end
end

-- Start the job (change the command as needed)
local job_id = vim.fn.jobstart("ping -c 5 google.com", {
  stdout_buffered = false,  -- stream output immediately
  on_stdout = function(_, data, _)
    if data then
      -- data is a list of lines; append them to the buffer
      append_to_buf(data)
    end
  end,
  on_stderr = function(_, data, _)
    if data then
      -- Append stderr lines as well
      append_to_buf(data)
    end
  end,
  on_exit = function(_, exit_code, _)
    -- Notify when the job finishes
    append_to_buf({"", "Job finished with exit code: " .. exit_code})
  end,
})
