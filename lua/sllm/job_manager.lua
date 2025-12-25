-- Module definition ==========================================================
local JobManager = {}
local H = {}

-- Helper data ================================================================
H.utils = require('sllm.utils')
H.llm_job_id = nil
H.stdout_acc = ''

-- Public API =================================================================
--- Check if a job is currently running.
---@return boolean `true` if a job is active, `false` otherwise.
function JobManager.is_busy() return H.llm_job_id ~= nil end

---Execute a command synchronously and capture its output.
---@param cmd_raw string Command to execute (supports vim cmd expansion)
---@return string Combined stdout/stderr output, labeled if both present
function JobManager.exec_cmd_capture_output(cmd_raw)
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
function JobManager.start(cmd, hook_on_newline, hook_on_exit)
  H.stdout_acc = ''
  H.llm_job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    pty = true,
    on_stdout = function(_, data, _)
      if not data then return end
      for _, chunk in ipairs(data) do
        if chunk ~= '' then
          -- 1) Accumulate chunks
          H.stdout_acc = H.stdout_acc .. chunk

          -- 2) Split on '\r' and flush each line
          local cr_pos = H.stdout_acc:find('\r', 1, true)
          while cr_pos do
            local line = H.stdout_acc:sub(1, cr_pos - 1)
            hook_on_newline(H.utils.strip_ansi_codes(line))
            H.stdout_acc = H.stdout_acc:sub(cr_pos + 1)
            cr_pos = H.stdout_acc:find('\r', 1, true)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          hook_on_newline(H.utils.strip_ansi_codes(line))
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      -- Flush leftover text without a trailing '\r'
      if H.stdout_acc ~= '' then
        hook_on_newline(H.stdout_acc)
        H.stdout_acc = ''
      end
      H.llm_job_id = nil
      hook_on_exit(exit_code)
    end,
  })
end

--- Stop the currently running job, if any, and reset state.
---@return nil
function JobManager.stop()
  if H.llm_job_id then
    vim.fn.jobstop(H.llm_job_id)
    H.llm_job_id = nil
    H.stdout_acc = ''
  end
end

return JobManager
