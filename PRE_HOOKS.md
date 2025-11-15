# Pre-Hooks and Post-Hooks

## Overview

Pre-hooks and post-hooks allow you to run shell commands before and after LLM queries. This is particularly useful for dynamically generating context that the LLM can then use, without any manual file management.

**Key Feature**: When `add_to_context = true`, stdout from your command is automatically captured to a temporary file, added to context, and cleaned up after the query completes - no manual file paths or cleanup needed!

## Use Cases

- **Dynamic Context Generation**: Use tools like `context-vacuum` to generate project-specific context automatically
- **Git Context**: Automatically include recent commits, diffs, or branch status
- **Build/Test Output**: Capture compiler errors or test failures
- **Project Structure**: Generate file trees or dependency graphs
- **Logging**: Track query history or completion events

## Configuration

### Basic Example with context-vacuum

```lua
require("sllm").setup({
  -- Other config options...
  default_model = "claude-sonnet-4.5",

  -- Pre-hooks run BEFORE the LLM query
  pre_hooks = {
    {
      command = "context-vacuum generate",
      add_to_context = true,  -- Captures stdout to temp file and adds to context
    },
  },

  -- Post-hooks run AFTER the LLM response (optional)
  post_hooks = {
    {
      command = "echo 'Query completed at' $(date) >> ~/.sllm_history",
    },
  },
})
```

**That's it!** Now every time you ask the LLM a question, `context-vacuum generate` will run automatically, its output will be added to context, and everything will be cleaned up when done.

### Multiple Hooks

You can configure multiple pre-hooks and post-hooks. They execute in the order defined:

```lua
require("sllm").setup({
  pre_hooks = {
    -- Hook 1: Generate project context
    {
      command = "tree -L 2 -I 'node_modules|.git'",
      add_to_context = true,
    },
    -- Hook 2: Get git information
    {
      command = "git log --oneline -10 && git status",
      add_to_context = true,
    },
    -- Hook 3: Run without adding to context (side effects only)
    {
      command = "echo 'Starting query...' >> /tmp/sllm.log",
      add_to_context = false,
    },
  },
  post_hooks = {
    {
      command = "echo 'Query finished' >> /tmp/sllm.log",
    },
  },
})
```

## How It Works

### Pre-Hooks

When you trigger `ask_llm` (e.g., `<leader>ss`), the following happens:

1. **Execute Each Pre-Hook**: Commands run sequentially in the order defined
2. **Capture Output**: If `add_to_context = true`, stdout is captured
3. **Create Temp File**: Captured output is written to a temporary file (via `vim.fn.tempname()`)
4. **Add to Context**: The temp file is automatically added to the LLM context
5. **Continue Normal Flow**: The LLM query executes with all context (including pre-hook outputs)

### Post-Hooks

After the LLM response completes:

1. **Execute Each Post-Hook**: Commands run sequentially
2. **Cleanup Temp Files**: All temporary files created by pre-hooks are automatically deleted
3. **Reset Context**: If configured, context is reset for the next query

## Configuration Schema

### Pre-Hook

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `command` | string | Yes | - | Shell command to execute |
| `add_to_context` | boolean | No | `false` | Whether to capture stdout and add to LLM context |

### Post-Hook

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `command` | string | Yes | - | Shell command to execute |

## Examples

### Example 1: context-vacuum Integration

```lua
pre_hooks = {
  {
    command = "context-vacuum generate",
    add_to_context = true,
  },
},
```

This runs `context-vacuum generate`, captures its output, creates a temp file, and adds it to context automatically.

### Example 2: Project Overview

```lua
pre_hooks = {
  {
    command = [[
      echo "# Project Structure" && \
      tree -L 2 -I 'node_modules|.git|dist' && \
      echo "" && \
      echo "# Git Status" && \
      git status --short
    ]],
    add_to_context = true,
  },
},
```

### Example 3: Test Failures

```lua
pre_hooks = {
  {
    command = "npm test 2>&1 | grep -A 5 'FAIL' || echo 'No test failures'",
    add_to_context = true,
  },
},
```

### Example 4: Git History Context

```lua
pre_hooks = {
  {
    command = "git log --oneline -10 && echo '' && git status",
    add_to_context = true,
  },
},
```

Automatically includes recent git history and current status in every query.

### Example 5: Multiple Hooks with Logging

```lua
pre_hooks = {
  {
    command = "echo $(date): Query started >> ~/.sllm_log",
    add_to_context = false,  -- Just logging, not adding to context
  },
  {
    command = "context-vacuum generate",
    add_to_context = true,   -- This gets added to context
  },
},
post_hooks = {
  {
    command = "echo $(date): Query completed >> ~/.sllm_log",
  },
},
```

This example shows using multiple hooks: one for logging (no context), one for context generation.

## Safety Features

### Automatic Temp File Cleanup

All temporary files created by pre-hooks are tracked and automatically deleted after the query completes. You don't need to manually clean them up.

### No File Path Required

Unlike manually managing context files, you don't need to:
- Choose file paths
- Remember to delete files
- Worry about file conflicts

The plugin handles all of this automatically using `vim.fn.tempname()`.

## Debugging

If your pre-hooks aren't working as expected:

1. **Test Command Manually**: Run your command in a terminal to verify it produces the expected output
2. **Check Notifications**: Look for `[sllm] pre-hook executed, added to context` notification when you trigger a query
3. **Verify Plugin Version**: Make sure you're on the `pre-hook` branch with `:Lazy sync`
4. **Verify add_to_context**: Ensure `add_to_context = true` if you want output added to context
5. **Check Context**: Run `:lua print(vim.inspect(require('sllm.context_manager').get()))` to see loaded context

## Performance Considerations

Pre-hooks execute **synchronously** before the LLM query. Keep commands fast (ideally < 1 second) to avoid delays.

For long-running commands, consider:
- Running them in the background and reading cached results
- Using simpler/faster alternatives
- Only enabling them when needed

## Advanced Patterns

### Chaining Commands

```lua
pre_hooks = {
  {
    command = "command1 && command2 && command3",
    add_to_context = true,
  },
},
```

### Error Handling

```lua
pre_hooks = {
  {
    -- Use || to provide fallback on error
    command = "git log --oneline -10 || echo 'Not a git repository'",
    add_to_context = true,
  },
},
```

## Comparison to Manual Context Management

### Before (Manual)
```bash
# Terminal
$ tree -L 2 > /tmp/context.txt
```

```lua
-- In Neovim, manually add file
:lua require('sllm').add_file_to_ctx()  -- type /tmp/context.txt
-- Ask query
-- Remember to delete /tmp/context.txt later
```

### After (With Pre-Hooks)
```lua
-- One-time setup in config
pre_hooks = {
  { command = "tree -L 2", add_to_context = true },
}
-- Just ask queries - context generated and cleaned up automatically!
```

## Future Enhancements

Potential future features:
- Conditional hook execution (only run if condition is met)
- Async hook execution (don't block the UI)
- Hook templates/presets
- Dynamic command generation (command as a Lua function)
- Per-query hook selection (choose which hooks to run)
- Hook execution timeout and error handling

## Installation

To use pre-hooks and post-hooks, you need to use the `pre-hook` branch:

```lua
{
  "brojonat/sllm.nvim",  -- or your fork
  branch = "pre-hook",
  dependencies = { "echasnovski/mini.nvim" },
  config = function()
    require("sllm").setup({
      -- Your config with pre_hooks and post_hooks
    })
  end,
}
```

After updating your config, run `:Lazy sync` to install/update.

## See Also

- [Main README](./README.md) - General plugin documentation
- [Example Configuration](./examples/pre_hook_config.lua) - Full example config
- [Design Document](./PRE_HOOK_DESIGN.md) - Technical implementation details
