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

- **Lightweight wrapper**: ~1200 lines of Lua, delegates heavy lifting to `llm`
  CLI
- **Philosophy**: Explicit control, co-pilot (not autonomous agent)
- **Unique Feature**: On-the-fly Python function tools (`<leader>sF`)
- **Architecture**: mini.nvim-inspired patterns (ModuleName + H helper pattern)
- **Testing**: 58 unit tests using mini.test
- **License**: MIT

---

## Project Structure

```
sllm.nvim/
├── lua/sllm/
│   ├── init.lua              # Main module (Sllm) - Public API
│   ├── backend/llm.lua       # CLI command construction
│   ├── context_manager.lua   # Context tracking
│   ├── history_manager.lua   # Conversation history
│   ├── job_manager.lua       # Async job execution
│   ├── ui.lua               # Buffer/window management
│   ├── utils.lua            # Helper functions
│   └── health.lua           # Health check module
├── tests/                   # Unit tests (mini.test)
├── doc/sllm.txt            # Auto-generated help (583 lines)
├── scripts/minidoc.lua     # Documentation generator
├── README.md               # User documentation
├── PREFACE.md              # Philosophy & comparison
└── Makefile                # Build automation
```

---

## Architecture: mini.nvim H-Pattern

**All modules follow this pattern:**

```lua
local ModuleName = {}  -- Public API (exported)
local H = {}           -- Helper functions and internal state

-- Helper data
H.state = {}           -- Internal state
H.helper_func = function() ... end  -- Private helpers

-- Public API
function ModuleName.public_func() ... end

return ModuleName
```

**Module Responsibilities:**

| Module            | Responsibility                    | Exports          |
| ----------------- | --------------------------------- | ---------------- |
| `init.lua`        | Main entry point, config, keymaps | `Sllm`           |
| `backend/llm.lua` | Build `llm` CLI commands          | `Backend`        |
| `context_manager` | Track files, snippets, tools      | `ContextManager` |
| `history_manager` | Fetch conversation history        | `HistoryManager` |
| `job_manager`     | Async job execution               | `JobManager`     |
| `ui.lua`          | Buffer/window management          | `UI`             |
| `utils.lua`       | Helper utilities                  | `Utils`          |
| `health.lua`      | Neovim health check               | `M.check`        |

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

1. **Identify the right module** (see table above)
2. **Follow H-pattern**:
   ```lua
   function ModuleName.new_feature()
     H.validate_input()
     H.process_data()
   end

   function H.validate_input()
     -- Internal helper
   end
   ```
3. **Add documentation** (LuaCATS annotations):
   ```lua
   ---@tag sllm.new_feature()
   --- Brief description.
   ---@return nil
   function Sllm.new_feature()
   ```
4. **Add tests** in appropriate test file
5. **Add keymap** (if user-facing) in `H.default_config.keymaps`
6. **Update README.md** for user documentation
7. **Run checks**: `make format && make lint && make test && make doc`

---

## Philosophy & Design Decisions

### Wrapper Architecture

**Decision**: Delegate to `llm` CLI instead of implementing API clients

**Why**:

- Simplicity: Keep plugin lightweight (~1200 lines)
- Reliability: `llm` is battle-tested
- Extensibility: Instant access to entire `llm` plugin ecosystem
- Maintainability: No need to track API changes

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

**Last Updated**: 2025-12-26 | **Maintained By**: mozanunal

**For AI Assistants**: This document should be read in full before making
changes to the codebase.
