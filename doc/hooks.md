# Hooks {#sllm-hooks}

Hooks let you run shell commands before or after an LLM request.

## Pre-hooks

- Run before the LLM starts.
- Optional `add_to_context` flag captures stdout/stderr into the context.

Example:

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'git diff --cached', add_to_context = true },
    { command = 'echo Starting request', add_to_context = false },
  },
})
```

Notes:

- Output is stored as a snippet with the command name.
- Snippets are cleared after each prompt if `reset_ctx_each_prompt = true`.
- Hooks run synchronously in order.

## Post-hooks

- Run after the response finishes (success or failure).
- Output is not captured; use for logging or notifications.

Example:

```lua
require('sllm').setup({
  post_hooks = {
    { command = 'date >> ~/.sllm_history.log' },
    { command = "osascript -e 'display notification \"LLM request completed\" with title \"SLLM\"'" },
  },
})
```

Tips:

- Use `%` in commands to expand to the current file path.
- Keep commands fast to avoid blocking the response finish.
