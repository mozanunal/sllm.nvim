local M = {}

local llm_job_id = nil
local stdout_acc = ''
local ansi_escape_pattern = '[\27\155][][()#;?%][0-9;]*[A-Za-z@^_`{|}~]'

--- Removes ANSI escape codes from a string.
-- @param text string The input string possibly containing ANSI escape codes.
-- @return string The string with ANSI escape codes removed.
local function strip_ansi_codes(text) return text:gsub(ansi_escape_pattern, '') end

M.is_busy = function()
  if llm_job_id then
    return true
  else
    return false
  end
end

M.start = function(cmd, hook_on_newline, hook_on_exit)
  llm_job_id = vim.fn.jobstart(cmd, {
    stdout_buffer = false,
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
            hook_on_newline(strip_ansi_codes(line))

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
          hook_on_newline(strip_ansi_codes(line))
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      -- if there’s leftover text without a trailing '\r', you can flush it here:
      if stdout_acc ~= '' then
        hook_on_newline(stdout_acc)
        stdout_acc = ''
      end
      llm_job_id = nil
      hook_on_exit(exit_code)
    end,
  })
end

M.stop = function()
  if llm_job_id then
    vim.fn.jobstop(llm_job_id)
    llm_job_id = nil
    stdout_acc = ''
  end
end

return M
