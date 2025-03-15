-- File: lua/sllm/init.lua
local M = {}

-- Store our scratch buffer handle
local llm_buf

-- Create or get a scratch buffer
local function get_llm_buffer()
  if not (llm_buf and vim.api.nvim_buf_is_valid(llm_buf)) then
    llm_buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch buffer
  end
  return llm_buf
end

-- Show the buffer in a vertical split and set window-local options
local function show_llm_buffer()
  local buf = get_llm_buffer()

  -- Check if it's already in a window
  local wins = vim.api.nvim_list_wins()
  local already_open = false
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_get_buf(w) == buf then
      already_open = true
      vim.api.nvim_set_current_win(w)
      break
    end
  end

  if not already_open then
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
  end

  -- Because 'wrap' is a *window-local* option, set it with `nvim_win_set_option`
  vim.api.nvim_win_set_option(0, "wrap", true)
  vim.api.nvim_win_set_option(0, "linebreak", true)

  -- For demonstration, set the buffer filetype to markdown (a *buffer-local* option)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
end

-- Append new lines at the end of the LLM buffer
local function append_lines(lines)
  local buf = get_llm_buffer()
  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
end

-- Asynchronously run a command via jobstart, appending output as it arrives
local function run_llm_command(cmd, user_prompt)
  show_llm_buffer()
  -- Prepend the user's prompt so we can see it
  append_lines({ ">>> " .. user_prompt })

  -- Start an async job
  local job_id = vim.fn.jobstart(cmd, {
    -- By default, data is received in chunks. We set this to false so we get
    -- partial lines as they come in. If `llm` doesn't flush, you still may
    -- only see output in large chunks.
    stdout_buffered = false,
    -- Called each time we get data on stdout
    on_stdout = function(_, data, _)
      if data then
        -- Filter out any empty table entries that might come from job events
        local lines = {}
        for _, line in ipairs(data) do
          -- Sometimes last chunk can be empty
          if line ~= "" then
            table.insert(lines, line)
          end
        end
        if #lines > 0 then
          append_lines(lines)
          -- Optionally scroll to the bottom
          vim.cmd("normal! G")
        end
      end
    end,
    -- Called each time we get data on stderr
    on_stderr = function(_, data, _)
			print("ERROR" .. data)
      -- You can handle or append stderr lines if you want
      -- For example, you could append them to the buffer with a different prefix
    end,
    -- Called when the job finishes
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        append_lines({ "", "[llm command exited with code " .. exit_code .. "]" })
      else
        -- Possibly append a divider or do nothing
        append_lines({ "" })
      end
    end,
  })

  if job_id <= 0 then
    append_lines({ "[ERROR starting job for cmd: " .. cmd .. "]" })
  end
end

function M.ask_llm()
  local continue = vim.fn.input("Continue previous chat? (y/N): "):lower() == "y"
  local user_input = vim.fn.input("Prompt: ")
  if user_input == "" then
    print("No prompt provided.")
    return
  end

  -- Build the command
  local cmd
  if continue then
    cmd = "llm -c " .. vim.fn.shellescape(user_input)
  else
    cmd = "llm " .. vim.fn.shellescape(user_input)
  end

  run_llm_command(cmd, user_input)
end

function M.setup()
  vim.api.nvim_create_user_command(
    "AskLLM",
    function() M.ask_llm() end,
    { desc = "Send a prompt to the llm CLI tool asynchronously" }
  )
end

return M
