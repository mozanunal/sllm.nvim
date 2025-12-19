---@module "sllm.job_manager"
local M = {}

local llm_job_id = nil
local stdout_acc = ''
local ansi_escape_pattern = '[\27\155][][()#;?%][0-9;]*[A-Za-z@^_`{|}~]'

--- Remove ANSI escape codes from a string.
---@param text string The input string possibly containing ANSI escape codes.
---@return string The string with ANSI escape codes removed.
local function strip_ansi_codes(text) return text:gsub(ansi_escape_pattern, '') end

--- Check if a job is currently running.
---@return boolean `true` if a job is active, `false` otherwise.
function M.is_busy() return llm_job_id ~= nil end

---Execute a command synchronously and capture its output.
---@param cmd_raw string Command to execute (supports vim cmd expansion)
---@return string Combined stdout/stderr output, labeled if both present
function M.exec_cmd_capture_output(cmd_raw)
  local cmd = vim.fn.expandcmd(cmd_raw)
  local result = vim.system({ 'bash', '-c', cmd }, { text = true }):wait()
  local res_stdout = vim.trim(result.stdout or '')
  local res_stderr = vim.trim(result.stderr or '')
  local output = ''
  if res_stdout ~= '' then output = output .. '\nstdout:\n' .. res_stdout end
  if res_stderr ~= '' then output = output .. '\nstderr:\n' .. res_stderr end
  return output
end

--- Start a new job and stream its output line by line.
---
--- Splits on `'\r'` in the stdout buffer, strips ANSI codes, and calls
--- `hook_on_newline` for each line. Once the job exits, it flushes any
--- leftover, clears state, and calls `hook_on_exit`.
---
---@param cmd string|string[]                 Command or command-plus-args for `vim.fn.jobstart`.
---@param hook_on_newline fun(line: string)   Callback invoked on each decoded line.
---@param hook_on_exit fun(exit_code: integer) Callback invoked when the job exits.
---@return nil
function M.start(cmd, hook_on_newline, hook_on_exit)
  llm_job_id = vim.fn.jobstart(cmd, {
    stdout_buffer = false,
    pty = true,
    on_stdout = function(_, data, _)
      if not data then return end
      for _, chunk in ipairs(data) do
        if chunk ~= '' then
          -- 1) Accumulate chunks
          stdout_acc = stdout_acc .. chunk

          -- 2) Split on '\r' and flush each line
          local cr_pos = stdout_acc:find('\r', 1, true)
          while cr_pos do
            local line = stdout_acc:sub(1, cr_pos - 1)
            hook_on_newline(strip_ansi_codes(line))
            stdout_acc = stdout_acc:sub(cr_pos + 1)
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
      -- Flush leftover text without a trailing '\r'
      if stdout_acc ~= '' then
        hook_on_newline(stdout_acc)
        stdout_acc = ''
      end
      llm_job_id = nil
      hook_on_exit(exit_code)
    end,
  })
end

--- Stop the currently running job, if any, and reset state.
---@return nil
function M.stop()
  if llm_job_id then
    vim.fn.jobstop(llm_job_id)
    llm_job_id = nil
    stdout_acc = ''
  end
end

return M
