# Pre-Hook Feature Design

## Overview

This document outlines the design for adding pre-hook support to sllm.nvim. Pre-hooks are configurable shell commands that execute before running the `llm` CLI command, enabling dynamic context generation and preparation.

## Motivation

Users often need to dynamically generate context files based on the current state of their project, environment, or codebase. For example:
- Generating a project structure overview
- Collecting recent git history or diffs
- Aggregating documentation from multiple sources
- Running analysis tools and capturing their output
- Creating custom context summaries based on project-specific needs

Currently, users must manually create these files before adding them to the context. Pre-hooks automate this workflow.

## Use Cases

1. **Dynamic Project Context**
   - Generate a tree view of the project structure
   - List recently modified files
   - Capture git status and recent commits

2. **Code Analysis**
   - Run linters/formatters and capture their output
   - Generate documentation from code comments
   - Extract function/class signatures from multiple files

3. **Environment Information**
   - Capture relevant environment variables
   - List installed dependencies
   - Document system configuration

4. **Custom Aggregation**
   - Combine multiple files into a single context document
   - Filter/transform existing files before including them
   - Generate summaries from external tools

## Configuration Design

### Basic Configuration

```lua
require("sllm").setup({
  -- ... existing config options ...

  pre_hooks = {
    -- Simple hook: command generates a file that gets auto-added to context
    {
      name = "project_structure",
      command = "tree -L 3 -I 'node_modules|.git' > /tmp/sllm_project_tree.txt",
      output_file = "/tmp/sllm_project_tree.txt",
      enabled = true,
    },

    -- Hook with conditional execution
    {
      name = "git_context",
      command = "git log --oneline -10 > /tmp/sllm_git_log.txt && git status >> /tmp/sllm_git_log.txt",
      output_file = "/tmp/sllm_git_log.txt",
      enabled = true,
      condition = function()
        -- Only run if we're in a git repo
        return vim.fn.isdirectory(".git") == 1
      end,
    },

    -- Hook with dynamic command generation
    {
      name = "current_file_deps",
      command = function()
        local bufpath = vim.api.nvim_buf_get_name(0)
        return string.format("grep -r 'import.*%s' . > /tmp/sllm_deps.txt", vim.fn.fnamemodify(bufpath, ":t:r"))
      end,
      output_file = "/tmp/sllm_deps.txt",
      enabled = false, -- disabled by default, can be toggled
    },
  },

  -- Global pre-hook settings
  pre_hook_timeout = 5000, -- milliseconds, default timeout for all hooks
  pre_hook_on_error = "warn", -- "warn", "error", or "ignore"
})
```

### Hook Schema

Each pre-hook object supports:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique identifier for the hook |
| `command` | string \| function | Yes | Shell command to execute, or function returning command string |
| `output_file` | string \| nil | No | Path to output file that will be added to context. If nil, command runs but output isn't added to context |
| `enabled` | boolean | No | Whether hook is active (default: true) |
| `condition` | function | No | Function returning boolean; hook only runs if true |
| `timeout` | number | No | Override global timeout for this specific hook (milliseconds) |
| `cwd` | string | No | Working directory for command execution (default: current working directory) |

## Implementation Approach

### 1. Configuration Layer (`lua/sllm/init.lua`)

**Changes needed:**
- Extend `SllmConfig` type definition to include `pre_hooks`, `pre_hook_timeout`, and `pre_hook_on_error` fields
- Store pre-hook configuration in the config table
- Provide validation for hook configuration on setup

### 2. Pre-Hook Manager Module (`lua/sllm/pre_hook_manager.lua`)

**New module** to handle pre-hook execution:

```lua
---@class PreHook
---@field name string
---@field command string|function
---@field output_file string|nil
---@field enabled boolean
---@field condition function|nil
---@field timeout number|nil
---@field cwd string|nil

local M = {}

-- Store configured hooks
local hooks = {}

---Initialize pre-hook manager with configuration
---@param config table Pre-hook configuration
function M.setup(config)
  -- Store and validate hooks
end

---Execute all enabled pre-hooks
---@param on_complete function Callback when all hooks complete
---@param on_error function Callback on error
function M.execute_hooks(on_complete, on_error)
  -- Run hooks sequentially or in parallel
  -- Collect output files
  -- Return list of generated files to add to context
end

---Toggle a specific hook on/off
---@param hook_name string
function M.toggle_hook(hook_name)
  -- Enable/disable hook by name
end

---Get status of all hooks
---@return table Hook statuses
function M.get_status()
  -- Return list of hooks with their enabled status
end

return M
```

**Key responsibilities:**
- Store and validate hook configurations
- Execute hooks with proper error handling and timeouts
- Collect output files for context addition
- Provide hook management functions (enable/disable individual hooks)

### 3. Integration with ask_llm Flow

**Modify `M.ask_llm()` in `lua/sllm/init.lua`:**

Current flow:
```
User input → Show buffer → Check if busy → Get context → Build command → Execute
```

New flow with pre-hooks:
```
User input → Show buffer → Check if busy → Execute pre-hooks →
Get context + hook outputs → Build command → Execute
```

**Pseudocode:**

```lua
function M.ask_llm()
  if Utils.is_mode_visual() then M.add_sel_to_ctx() end
  input({ prompt = 'Prompt: ' }, function(user_input)
    -- ... validation ...

    Ui.show_llm_buffer(config.window_type, state.selected_model)
    if JobMan.is_busy() then
      notify('[sllm] already running, please wait.', vim.log.levels.WARN)
      return
    end

    -- NEW: Execute pre-hooks before building command
    PreHookManager.execute_hooks(
      function(hook_output_files)
        -- Add hook output files to context
        for _, file in ipairs(hook_output_files) do
          CtxMan.add_fragment(file)
        end

        -- Continue with existing flow
        local ctx = CtxMan.get()
        local prompt = CtxMan.render_prompt_ui(user_input)
        -- ... rest of existing code ...
      end,
      function(err)
        -- Handle pre-hook errors based on config
        if config.pre_hook_on_error == "error" then
          notify('[sllm] pre-hook failed: ' .. err, vim.log.levels.ERROR)
          return
        elseif config.pre_hook_on_error == "warn" then
          notify('[sllm] pre-hook warning: ' .. err, vim.log.levels.WARN)
          -- Continue anyway
        end
        -- "ignore" case: continue silently
      end
    )
  end)
end
```

### 4. New User Commands and Keymaps

Add functionality to manage hooks at runtime:

```lua
-- New functions in lua/sllm/init.lua
function M.toggle_pre_hook()
  -- Show picker with list of hooks, toggle selected one
end

function M.show_pre_hook_status()
  -- Display current status of all pre-hooks
end
```

**Optional keymaps:**
- `<leader>sh` - Toggle pre-hook
- `<leader>sH` - Show pre-hook status

### 5. Execution Strategy

**Sequential vs Parallel:**
- **Phase 1 (MVP):** Execute hooks sequentially for simplicity
- **Phase 2 (Future):** Add parallel execution option with configuration flag

**Timeout Handling:**
- Respect per-hook timeout if specified, otherwise use global timeout
- Kill process if timeout exceeded
- Report timeout as error/warning based on `pre_hook_on_error` setting

**Error Handling:**
- Capture stderr and stdout
- Non-zero exit codes treated as errors
- Missing output files treated as errors
- Behavior controlled by `pre_hook_on_error` configuration

## Implementation Phases

### Phase 1: MVP (Minimum Viable Product)
- [ ] Create `pre_hook_manager.lua` module
- [ ] Add configuration schema and validation
- [ ] Implement sequential hook execution
- [ ] Integrate with `ask_llm()` flow
- [ ] Add basic error handling
- [ ] Write unit tests for pre-hook manager

### Phase 2: Enhanced Management
- [ ] Add `toggle_pre_hook()` function with picker UI
- [ ] Add `show_pre_hook_status()` function
- [ ] Add optional keymaps for hook management
- [ ] Improve error messages and notifications

### Phase 3: Advanced Features (Future)
- [ ] Parallel hook execution option
- [ ] Hook execution caching (don't re-run if output file is recent)
- [ ] Pre-hook templates/presets
- [ ] Hook execution history/logging
- [ ] Support for hook dependencies (run hook A before hook B)

## Code Locations

### Files to Modify
- `lua/sllm/init.lua` - Add config options, integrate pre-hook execution in `ask_llm()`
- `lua/sllm/backend/llm.lua` - No changes needed (hooks transparent to backend)
- `lua/sllm/context_manager.lua` - No changes needed (hook outputs are regular files)

### Files to Create
- `lua/sllm/pre_hook_manager.lua` - New module for hook management
- `tests/test_pre_hook_manager.lua` - Unit tests for pre-hook manager

## Example Use Cases

### Example 1: Project Context Generator

```lua
{
  name = "project_overview",
  command = [[
    {
      echo "# Project Structure"
      tree -L 2 -I 'node_modules|.git|dist'
      echo -e "\n# Recent Changes"
      git log --oneline -5
      echo -e "\n# Current Branch"
      git branch --show-current
    } > /tmp/sllm_project_context.md
  ]],
  output_file = "/tmp/sllm_project_context.md",
  enabled = true,
}
```

### Example 2: Conditional Test Results

```lua
{
  name = "test_failures",
  command = "npm test 2>&1 | grep -A 5 'FAIL' > /tmp/sllm_test_failures.txt || true",
  output_file = "/tmp/sllm_test_failures.txt",
  enabled = false, -- Enable manually when debugging tests
  condition = function()
    return vim.fn.filereadable("package.json") == 1
  end,
}
```

### Example 3: Dynamic File Collection

```lua
{
  name = "related_files",
  command = function()
    local current_file = vim.api.nvim_buf_get_name(0)
    local basename = vim.fn.fnamemodify(current_file, ":t:r")
    return string.format(
      "find . -name '*%s*' -type f ! -path '*/node_modules/*' > /tmp/sllm_related.txt",
      basename
    )
  end,
  output_file = "/tmp/sllm_related.txt",
  enabled = true,
}
```

## Considerations

### Performance
- Pre-hooks execute synchronously before LLM call, adding latency
- Users should keep hooks fast (< 1-2 seconds ideally)
- Timeout protection prevents indefinite hanging
- Future: Consider background execution with caching

### Security
- Shell commands are powerful and potentially dangerous
- Users are responsible for their hook configurations
- Consider adding documentation warnings about command injection
- No sandboxing in MVP (same as `add_cmd_out_to_ctx` currently)

### File Management
- Hook output files are temporary by convention (e.g., `/tmp/sllm_*.txt`)
- Users responsible for cleanup (consider documenting this)
- Future: Option to auto-cleanup temp files after LLM response

### User Experience
- Clear notifications when hooks are running
- Informative error messages when hooks fail
- Easy discoverability of hook status and management
- Documentation with practical examples

## Testing Strategy

### Unit Tests
- Hook validation logic
- Command execution with mocked `vim.system`
- Timeout handling
- Error scenarios (missing output files, non-zero exit codes)
- Conditional hook execution

### Integration Tests
- Full flow: ask_llm → pre-hooks → context addition → command execution
- Hook toggle functionality
- Multiple hooks with different configurations

### Manual Testing Checklist
- [ ] Simple hook with static command
- [ ] Hook with dynamic command (function)
- [ ] Hook with condition (passes and fails)
- [ ] Hook timeout scenarios
- [ ] Multiple hooks executing in sequence
- [ ] Toggle hooks on/off
- [ ] Error handling for all error types
- [ ] Integration with existing context management

## Documentation Updates Needed

### README.md
- Add pre-hooks section to Configuration
- Add example use cases
- Document pre-hook management commands

### New Documentation
- Create `docs/PRE_HOOKS.md` with detailed guide
- Include common patterns and recipes
- Security considerations and best practices

## Future Enhancements

1. **Hook Templates** - Provide built-in hooks for common scenarios
2. **Hook Marketplace** - Share hooks with community
3. **Caching** - Skip re-running hooks if output is recent
4. **Async Execution** - Run hooks in background before user even asks
5. **Hook Chaining** - Output of one hook feeds into another
6. **Conditional Output Addition** - Only add to context if output meets criteria
7. **Per-Prompt Hook Selection** - Choose which hooks to run per query

## Open Questions

1. Should hooks run on every `ask_llm()` call, or only when explicitly triggered?
   - **Proposal:** Run on every call if `enabled = true`, with easy toggle mechanism

2. Should hook output files be automatically cleaned up?
   - **Proposal:** No auto-cleanup in MVP, document manual cleanup. Add option in Phase 3.

3. Should we support non-file outputs (e.g., directly pipe to context)?
   - **Proposal:** Phase 3 feature - allow hooks without `output_file` to stream to context

4. How to handle hooks that modify the workspace (not just generate files)?
   - **Proposal:** Document as valid use case, but warn about side effects

5. Should hook execution be cancellable?
   - **Proposal:** Yes, add to Phase 2 - cancel button should stop hooks too

## Summary

The pre-hook feature enables dynamic context generation by running configurable shell commands before each LLM invocation. This design balances flexibility, simplicity, and safety while maintaining backward compatibility with existing sllm.nvim functionality.

**Key Benefits:**
- Automates repetitive context generation tasks
- Enables project-specific customization
- Maintains clean separation from core LLM execution
- Easy to enable/disable individual hooks
- Extensible for future enhancements
