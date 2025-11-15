-- Example configuration showing how to use pre_hooks and post_hooks
-- This example demonstrates using context-vacuum to generate context

require("sllm").setup({
  -- Your existing configuration options
  llm_cmd = "llm",
  default_model = "gpt-4.1",
  show_usage = true,

  -- Pre-hooks: Run before each LLM query
  pre_hooks = {
    -- Example 1: Use context-vacuum to generate dynamic context
    {
      command = "context-vacuum generate",
      add_to_context = true,  -- Captures stdout and adds to context automatically
    },

    -- Example 2: Get git context (optional, can have multiple pre-hooks)
    -- {
    --   command = "git log --oneline -5 && git status",
    --   add_to_context = true,
    -- },

    -- Example 3: Run a command without adding to context (just for side effects)
    -- {
    --   command = "echo 'Starting LLM query...' >> /tmp/sllm_log.txt",
    --   add_to_context = false,
    -- },
  },

  -- Post-hooks: Run after LLM response completes
  post_hooks = {
    -- Example: Clean up or log completion
    {
      command = "echo 'LLM query completed' >> /tmp/sllm_log.txt",
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
