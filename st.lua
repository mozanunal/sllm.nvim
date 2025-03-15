-- File: lua/sllm_terminal.lua
local M = {}

-- Store references so we can reuse the same terminal/job:
M.llm_term_buf = nil
M.llm_term_job = nil

-- Returns true if a buffer is valid and still exists
local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

-- Check if the buffer is currently open in any window
local function find_window_for_buf(buf)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == buf then
      return w
    end
  end
  return nil
end

-- Create a new vertical-split terminal running `llm`
local function create_llm_terminal()
  -- Open a vertical split, then a terminal
  vim.cmd("vsplit | terminal llm chat")

  -- The buffer for this terminal is now the current buffer
  M.llm_term_buf = vim.api.nvim_get_current_buf()

  -- The job ID for the terminal job is stored in `b:terminal_job_id`
  M.llm_term_job = vim.b.terminal_job_id
end

--- Open (or reuse) the llm terminal in a vertical split
function M.open_llm_terminal()
  -- If we already have a valid buffer AND a valid job, just jump or re-split to it
  if valid_buf(M.llm_term_buf) and M.llm_term_job then
    -- Check if it's visible in any window
    local win = find_window_for_buf(M.llm_term_buf)
    if win then
      -- Already visible, jump there
      vim.api.nvim_set_current_win(win)
    else
      -- Not visible: open a new vertical split and display it
      vim.cmd("vsplit")
      vim.api.nvim_win_set_buf(0, M.llm_term_buf)
    end
  else
    -- The old terminal is gone or invalid: create a fresh one
    create_llm_terminal()
  end
end

--- Prompt the user for text and send it to the running llm terminal.
function M.send_prompt_to_llm()
  -- Make sure we have a running terminal first
  M.open_llm_terminal()

  if not (M.llm_term_job) then
    -- Something went wrong creating the terminal
    print("Error: No terminal job for LLM.")
    return
  end

  -- Ask for user input
  local user_input = vim.fn.input("Prompt: ")
  if user_input == "" then
    return
  end

  -- Send the prompt (plus a newline) into the terminal
  -- so that `llm` sees it as if typed by the user
  vim.api.nvim_chan_send(M.llm_term_job, user_input .. "\n")
end

--- Create commands for convenience
function M.setup()
  -- Opens or reuses the LLM terminal
  vim.api.nvim_create_user_command(
    "LLMTerm",
    function()
      M.open_llm_terminal()
    end,
    { desc = "Open or reuse a terminal running `llm` interactively" }
  )

  -- Prompts the user and sends that to the LLM terminal
  vim.api.nvim_create_user_command(
    "LLMPrompt",
    function()
      M.send_prompt_to_llm()
    end,
    { desc = "Prompt user then send input to `llm` in the terminal" }
  )
end

return M
