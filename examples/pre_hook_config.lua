-- Example configuration showing how to use pre_hooks and post_hooks
-- This demonstrates using context-vacuum to dynamically generate context

require("sllm").setup({
  -- Your existing configuration options
  llm_cmd = "llm",
  default_model = "claude-sonnet-4.5",
  show_usage = true,

  -- Pre-hooks: Run before each LLM query
  -- Stdout is automatically captured to temp files when add_to_context = true
  pre_hooks = {
    -- Example 1: Use context-vacuum to generate dynamic context
    {
      command = "context-vacuum generate",
      add_to_context = true,  -- Captures stdout to temp file and adds to context
    },

    -- Example 2: Get git context (optional, can have multiple pre-hooks)
    -- {
    --   command = "git log --oneline -5 && echo '' && git status",
    --   add_to_context = true,
    -- },

    -- Example 3: Run a command without adding to context (logging, etc.)
    -- {
    --   command = "echo $(date): Starting query >> ~/.sllm_log",
    --   add_to_context = false,  -- Just runs command, doesn't add output to context
    -- },
  },

  -- Post-hooks: Run after LLM response completes
  -- Temp files are automatically cleaned up after these run
  post_hooks = {
    -- Example: Log completion timestamp
    {
      command = "echo $(date): Query completed >> ~/.sllm_log",
    },
  },
})

-- How it works:
-- 1. User triggers ask_llm (e.g., <leader>ss)
-- 2. Pre-hooks execute in order
--    - If add_to_context = true, stdout is captured to a temp file
--    - Temp file is automatically added to context
-- 3. LLM query runs with context including pre-hook outputs
-- 4. Post-hooks execute after LLM response
-- 5. Temp files are automatically cleaned up
