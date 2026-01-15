# Hooks {#sllm-hooks}

Hooks let you run shell commands before or after LLM requests. Use them to add
context automatically, log interactions, or trigger notifications.

## Pre-hooks

Pre-hooks run before the LLM request starts. They can optionally capture their
output and add it to the context.

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'git diff --cached', add_to_context = true },
  },
})
```

**Options:**

- `command` (string, required) - Shell command to execute
- `add_to_context` (boolean, optional) - If true, captures stdout and adds it as
  a snippet. Default: false

## Post-hooks

Post-hooks run after the LLM response finishes (success or failure). Output is
not captured - use them for side effects.

```lua
require('sllm').setup({
  post_hooks = {
    { command = 'date >> ~/.sllm_log' },
  },
})
```

**Options:**

- `command` (string, required) - Shell command to execute

## Command expansion

Commands support vim's `%` expansion for the current file path:

```lua
pre_hooks = {
  { command = 'head -50 %', add_to_context = true },
}
```

This adds the first 50 lines of the current file to context.

## Execution details

- Hooks run through `bash -c`
- Pre-hooks run synchronously in order before the LLM request
- Post-hooks run synchronously in order after the response
- Non-zero exit codes don't abort the request
- Keep commands fast to avoid blocking

## Example: Git context

Add staged changes to every prompt:

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'git diff --cached', add_to_context = true },
  },
})
```

Now when you ask "Write a commit message", the LLM sees your staged diff.

## Example: Project context

Add project structure on each prompt:

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'tree -L 2 --noreport', add_to_context = true },
  },
})
```

## Example: Logging

Log all prompts to a file:

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'echo "--- $(date) ---" >> ~/.sllm_prompts.log' },
  },
  post_hooks = {
    { command = 'echo "Response received" >> ~/.sllm_prompts.log' },
  },
})
```

## Example: Notifications

Show a desktop notification when the response completes:

```lua
-- macOS
require('sllm').setup({
  post_hooks = {
    {
      command = [[osascript -e 'display notification "LLM response ready" with title "sllm.nvim"']],
    },
  },
})

-- Linux (notify-send)
require('sllm').setup({
  post_hooks = {
    { command = 'notify-send "sllm.nvim" "LLM response ready"' },
  },
})
```

## Example: Test results

Add test output to help debug failures:

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'make test 2>&1 | tail -50', add_to_context = true },
  },
})
```

Now ask "Why are these tests failing?" and the LLM sees recent test output.

## Example: LSP diagnostics (alternative)

While `/diagnostics` adds buffer diagnostics, you can use hooks for project-wide
issues:

```lua
require('sllm').setup({
  pre_hooks = {
    { command = 'npx tsc --noEmit 2>&1 | head -30', add_to_context = true },
  },
})
```

## Combining with context reset

By default, context is cleared after each prompt. Snippets added by pre-hooks
are also cleared.

To keep hook output across turns:

```lua
require('sllm').setup({
  reset_ctx_each_prompt = false,
  pre_hooks = {
    { command = 'git status --short', add_to_context = true },
  },
})
```

Now the git status stays in context for follow-up questions.

## Conditional hooks

For conditional logic, use shell conditionals in the command:

```lua
pre_hooks = {
  {
    command = '[ -f package.json ] && cat package.json | head -20',
    add_to_context = true,
  },
}
```

This only adds package.json if it exists.

## Performance tips

- Keep hooks fast (under 1 second ideally)
- Use `head` or `tail` to limit output size
- Pre-hooks block the prompt, so avoid slow commands
- Post-hooks block showing "response complete", keep them quick
- For expensive operations, consider using `/command` manually instead
