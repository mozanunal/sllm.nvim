# CLAUDE.md - AI Assistant Guide for sllm.nvim

This document provides essential context for AI coding assistants working on
**sllm.nvim**.

---

## Project Overview

**sllm.nvim** is a Neovim plugin that integrates Simon Willison's
[`llm`](https://llm.datasette.io/en/stable/) CLI directly into Neovim. It
provides a lightweight, focused "co-pilot" experience for interacting with Large
Language Models without leaving the editor.

### Key Characteristics

- **Lightweight wrapper**: ~2800 lines of Lua, delegates heavy lifting to `llm`
  CLI
- **Philosophy**: Explicit control, co-pilot (not autonomous agent)
- **Unique Feature**: On-the-fly Python function tools (`<leader>sF`)
- **Architecture**: mini.nvim-inspired patterns (ModuleName + H helper pattern)
- **Testing**: 38 unit tests using mini.test
- **License**: MIT

---

## Project Structure

```
sllm.nvim/
├── lua/sllm/
│   ├── init.lua              # Main module (~2100 lines)
│   │                         # - Public API (Sllm.*)
│   │                         # - H.* helper functions (context, ui, job, history, utils)
│   │                         # - H.state (consolidated state management)
│   │                         # - H.ANIMATION_FRAMES (constants)
│   ├── backend/
│   │   ├── init.lua          # Backend registry
│   │   ├── base.lua          # Base backend class
│   │   └── llm.lua           # LLM CLI backend implementation
│   └── health.lua            # Health check module
├── tests/                    # Unit tests (mini.test)
│   └── test_backend.lua      # Backend integration tests (38 tests)
├── doc/sllm.txt              # Auto-generated help
├── scripts/minidoc.lua       # Documentation generator
├── README.md                 # User documentation
├── PREFACE.md                # Philosophy & comparison
└── Makefile                  # Build automation
```

---

## Architecture: mini.nvim H-Pattern

**All modules follow this pattern:**

```lua
local ModuleName = {}  -- Public API (exported)
local H = {}           -- Helper functions and internal state

-- Constants (UPPERCASE naming convention)
H.ANIMATION_FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

-- Consolidated state
H.state = {
  -- Main state
  continue = nil,
  selected_model = nil,

  -- Nested sub-states for logical grouping
  context = { fragments = {}, snips = {}, tools = {}, functions = {} },
  ui = { llm_buf = nil, animation_timer = nil, ... },
  job = { llm_job_id = nil, stdout_acc = '' },
}

-- Helper functions (prefixed by domain)
H.context_get = function() ... end       -- Context helpers
H.ui_show_llm_buffer = function() ... end  -- UI helpers
H.job_start = function() ... end         -- Job helpers
H.history_get_conversations = function() ... end  -- History helpers
H.utils_parse_json = function() ... end  -- Utility helpers

-- Public API
function ModuleName.public_func()
  H.helper_func()  -- Use internal helpers
end

return ModuleName
```

**State Organization Rules:**
- Constants at the top using UPPERCASE naming
- All state consolidated in `H.state` with logical nesting
- Helper functions prefixed by domain (context_, ui_, job_, etc.)
- Public API functions in ModuleName namespace

**Module Responsibilities:**

| Module              | Responsibility                                                                 | Exports  |
| ------------------- | ------------------------------------------------------------------------------ | -------- |
| `init.lua`          | Main module with all functionality:                                            | `Sllm`   |
|                     | - Public API (config, keymaps, commands)                                       |          |
|                     | - H.context\_\* (context tracking: files, snippets, tools)                     |          |
|                     | - H.ui\_\* (buffer/window management, loading indicators)                      |          |
|                     | - H.job\_\* (async job execution, streaming)                                   |          |
|                     | - H.history\_\* (conversation history formatting)                              |          |
|                     | - H.utils\_\* (utilities: JSON parsing, buffer ops, visual selection)          |          |
|                     | - H.state (consolidated state: main, context, ui, job)                         |          |
| `backend/base.lua`  | Base backend class with OOP-style inheritance                                  | `Base`   |
| `backend/llm.lua`   | LLM CLI backend implementation (commands, models, tools, templates, history)   | `Backend`|
| `backend/init.lua`  | Backend registry for pluggable backends                                        | `M`      |
| `health.lua`        | Neovim health check (`:checkhealth sllm`)                                      | `M.check`|

---

## Development Workflow

### Common Commands

```bash
make              # Run all checks (format, lint, test)
make format       # Format with stylua
make lint         # Lint with luacheck
make test         # Run unit tests (mini.test)
make doc          # Generate documentation

# Health check
nvim +"checkhealth sllm" +"quit"
```

### Code Style

- **Indentation**: 2 spaces
- **Quotes**: Single quotes
- **Line length**: 120 characters max
- **Naming**: `snake_case` for functions/variables, `PascalCase` for modules
- **Formatter**: stylua (`.stylua.toml`)

### Testing

```lua
-- Test structure (mini.test)
local new_set = MiniTest.new_set

T['ModuleName'] = new_set({
  hooks = { pre_case = function() end },
})

T['ModuleName']['function()'] = function()
  expect.no_error(function() ModuleName.function() end)
end
```

Run: `make test` or
`nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()" -c "quit"`

---

## Adding a New Feature

1. **Determine feature domain** (context, UI, job, history, or public API)

2. **Add state if needed** to `H.state`:
   ```lua
   -- In init.lua, within H.state initialization
   H.state = {
     -- Add new state in appropriate section
     my_new_state = nil,

     -- Or add to existing nested state
     ui = {
       -- existing ui state...
       my_ui_state = false,
     },
   }
   ```

3. **Create helper function(s)** with domain prefix:
   ```lua
   -- Helper function (internal only)
   H.domain_validate_input = function()
     -- Internal helper logic
   end

   H.domain_process_data = function()
     H.domain_validate_input()
     -- Access state: H.state.my_new_state
   end
   ```

4. **Create public API function** (if user-facing):
   ```lua
   ---@tag sllm.new_feature()
   --- Brief description.
   ---@return nil
   Sllm.new_feature = function()
     H.domain_process_data()  -- Call helper
   end
   ```

5. **Add tests** in `tests/test_backend.lua` (public API level only)

6. **Add keymap** (if user-facing) in `H.default_config.keymaps`

7. **Update README.md** for user documentation

8. **Run checks**: `make format && make lint && make test && make doc`

**Key Principles:**
- Keep helper functions in logical domain groups (context_, ui_, job_, etc.)
- Always use `H.state.*` for state access, never separate variables
- Test at the public API level, not helper function level
- Follow UPPERCASE convention for new constants

---

## Philosophy & Design Decisions

### Wrapper Architecture

**Decision**: Delegate to `llm` CLI instead of implementing API clients

**Why**:

- Simplicity: Keep plugin lightweight (~2800 lines, single main module)
- Reliability: `llm` is battle-tested
- Extensibility: Instant access to entire `llm` plugin ecosystem
- Maintainability: No need to track API changes

### Consolidated Module Design

**Decision**: Merge separate modules (context, UI, job, history, utils) into init.lua as H.\* helpers

**Why**:

- Simplicity: Single file easier to navigate and understand
- Cohesion: Related functionality kept together
- Performance: No module loading overhead
- State management: Single H.state makes data flow explicit
- Maintainability: Fewer files to keep in sync

### Explicit Context Control

**Decision**: User manually adds context, no automatic guessing

**Why**:

- Predictability: Users know exactly what LLM sees
- Security: No accidental sending of sensitive files
- Performance: No expensive filesystem scanning
- Transparency: Clear mental model

---

## Common Issues & Solutions

### LLM Command Not Found

```lua
require("sllm").setup({
  llm_cmd = "/full/path/to/llm",
})
```

### No Models Available

```bash
llm install llm-openai
llm keys set openai
llm models list
```

### Context Not Persisting

```lua
require("sllm").setup({
  reset_ctx_each_prompt = false,
})
```

---

## Key Resources

- **llm CLI**: https://llm.datasette.io/en/stable/
- **mini.nvim**: https://github.com/echasnovski/mini.nvim
- **Repository**: https://github.com/mozanunal/sllm.nvim
- **Issues**: https://github.com/mozanunal/sllm.nvim/issues

---

## Guidelines for AI Assistants

1. **Architecture**: Always use ModuleName + H pattern
2. **Documentation**: Add LuaCATS annotations and update README.md
3. **Testing**: Write tests for new features
4. **Style**: Run `make format` before committing
5. **Philosophy**: Maintain explicit control, keep wrapper simple
6. **Compatibility**: Preserve backward compatibility

---

**Last Updated**: 2026-01-11 | **Maintained By**: mozanunal

**For AI Assistants**: This document should be read in full before making
changes to the codebase.
