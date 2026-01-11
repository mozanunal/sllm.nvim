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
--- Splits on `'\n'` in the stdout buffer, strips ANSI codes, and calls
--- `hook_on_stdout_line` for each line. Handles stderr separately via
--- `hook_on_stderr_line`. Once the job exits, it flushes any leftover,
--- clears state, and calls `hook_on_exit`.
---
---@param cmd string|string[]                      Command or command-plus-args for `vim.fn.jobstart`.
---@param hook_on_stdout_line fun(line: string)    Callback invoked on each decoded stdout line.
---@param hook_on_stderr_line fun(line: string)    Callback invoked on each decoded stderr line.
---@param hook_on_exit fun(exit_code: integer)     Callback invoked when the job exits.
---@return nil
function JobManager.start(cmd, hook_on_stdout_line, hook_on_stderr_line, hook_on_exit)
  H.stdout_acc = ''

  -- Merge current environment with unbuffered settings
  local job_env = vim.fn.environ()
  job_env.PYTHONUNBUFFERED = '1'
  job_env.PYTHONDONTWRITEBYTECODE = '1'

  H.llm_job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    pty = true, -- Use pty=true for proper streaming (stderr merges into stdout)
    on_stdout = function(_, data, _)
      if not data then return end
      for _, chunk in ipairs(data) do
        if chunk ~= '' then
          -- 1) Accumulate chunks
          H.stdout_acc = H.stdout_acc .. chunk

          -- 2) Split on '\n' and flush each line
          local nl_pos = H.stdout_acc:find('\n', 1, true)
          while nl_pos do
            local line = H.stdout_acc:sub(1, nl_pos - 1)
            -- Strip trailing \r if present (handles \r\n line endings)
            line = line:gsub('\r$', '')
            local stripped = H.utils.strip_ansi_codes(line)

            -- With pty=true, stderr is merged into stdout
            -- Detect token usage lines and route to stderr handler
            if stripped:match('Token usage:') or stripped:match('^Tool call:') then
              hook_on_stderr_line(stripped)
            else
              hook_on_stdout_line(stripped)
            end

            H.stdout_acc = H.stdout_acc:sub(nl_pos + 1)
            nl_pos = H.stdout_acc:find('\n', 1, true)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      -- With pty=true, stderr is redirected to stdout, so this won't be called much
      -- But keep it for safety
      if not data then return end
      for _, line in ipairs(data) do
        if line ~= '' then hook_on_stderr_line(H.utils.strip_ansi_codes(line)) end
      end
    end,
    on_exit = function(_, exit_code, _)
      -- Flush leftover stdout without a trailing '\n'
      if H.stdout_acc ~= '' then
        local line = H.stdout_acc:gsub('\r$', '')
        local stripped = H.utils.strip_ansi_codes(line)
        if stripped:match('Token usage:') or stripped:match('^Tool call:') then
          hook_on_stderr_line(stripped)
        else
          hook_on_stdout_line(stripped)
        end
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
