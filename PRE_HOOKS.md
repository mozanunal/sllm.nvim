# Pre-Hooks and Post-Hooks

## Overview

Pre-hooks and post-hooks allow you to run shell commands before and after LLM queries. This is particularly useful for dynamically generating context files that the LLM can then use.

## Use Cases

- **Dynamic Context Generation**: Generate project context, file trees, or summaries on-the-fly
- **Git Context**: Automatically include recent commits, diffs, or branch information
- **Build/Test Output**: Capture compiler errors or test failures
- **Environment Setup**: Prepare temporary files or gather system information
- **Cleanup**: Remove temporary files or log query completion

## Configuration

### Basic Example

```lua
require("sllm").setup({
  pre_hooks = {
    {
      command = "context-vacuum generate",
      add_to_context = true,
    },
  },
  post_hooks = {
    {
      command = "echo 'Query completed'",
    },
  },
})
```

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

### Example 4: Conditional Execution with Script

Create a shell script `pre_hook.sh`:

```bash
#!/bin/bash
# Only generate context if in a git repo
if [ -d .git ]; then
  git log --oneline -10
  git diff --stat
else
  echo "Not in a git repository"
fi
```

Then configure:

```lua
pre_hooks = {
  {
    command = "./pre_hook.sh",
    add_to_context = true,
  },
},
```

### Example 5: Logging and Cleanup

```lua
pre_hooks = {
  {
    command = "date '+%Y-%m-%d %H:%M:%S - Starting query' >> ~/.sllm_history",
    add_to_context = false,  -- Just logging, not adding to context
  },
  {
    command = "context-vacuum generate",
    add_to_context = true,
  },
},
post_hooks = {
  {
    command = "date '+%Y-%m-%d %H:%M:%S - Query completed' >> ~/.sllm_history",
  },
},
```

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

1. **Check Command Output**: Run your command manually in the shell to verify it works
2. **Check Notifications**: sllm will notify when pre-hooks execute
3. **Verify add_to_context**: If you don't see the output in context, ensure `add_to_context = true`
4. **Check for Errors**: If the command fails, check your shell for error messages

## Performance Considerations

Pre-hooks execute **synchronously** before the LLM query. Keep commands fast (ideally < 1 second) to avoid delays.

For long-running commands, consider:
- Running them in the background and reading cached results
- Using simpler/faster alternatives
- Only enabling them when needed

## Advanced Patterns

### Dynamic Commands Based on Current File

You can use Neovim's Lua to make commands dynamic:

```lua
-- In your config, you'd need to make this dynamic, but here's the concept:
-- This would require modifying the plugin to support command functions
pre_hooks = {
  {
    command = "find . -name '*" .. vim.fn.expand('%:t:r') .. "*' -type f",
    add_to_context = true,
  },
},
```

*Note: Current implementation requires static command strings. Dynamic commands would be a future enhancement.*

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

## See Also

- [Main README](./README.md) - General plugin documentation
- [Example Configuration](./examples/pre_hook_config.lua) - Full example config
- [context-vacuum](https://github.com/yourusername/context-vacuum) - Context generation tool
