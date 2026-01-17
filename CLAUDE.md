# CLAUDE.md - AI Assistant Guide for sllm.nvim

## Overview

**sllm.nvim** is a Neovim plugin wrapping Simon Willison's
[`llm`](https://llm.datasette.io/) CLI. It's a lightweight co-pilot
for LLM interaction within the editor.

**Key traits**: Explicit context control, template-based modes, on-the-fly
Python function tools.

## Project Structure

```
lua/sllm/
├── init.lua          # Main module: Sllm.* (public API), H.* (helpers), H.state
├── backend/
│   ├── init.lua      # Backend registry
│   ├── base.lua      # Base backend class
│   └── llm.lua       # LLM CLI backend
└── health.lua        # :checkhealth sllm
templates/            # Native llm templates (sllm_chat, sllm_read, sllm_agent, sllm_complete)
tests/                # Unit tests (mini.test)
```

## Architecture: mini.nvim H-Pattern

```lua
local Sllm = {}  -- Public API (exported)
local H = {}     -- Helpers + internal state

H.CONSTANTS = {...}  -- UPPERCASE for constants
H.state = {          -- Consolidated state
  selected_model = nil,
  context = { fragments = {}, snips = {}, tools = {}, functions = {} },
  ui = { llm_buf = nil, ... },
  job = { llm_job_id = nil, stdout_acc = '' },
}

-- Helpers prefixed by domain
H.context_*    -- Context tracking
H.ui_*         -- Buffer/window management
H.job_*        -- Async job execution
H.history_*    -- Conversation history
H.utils_*      -- Utilities

Sllm.public_func = function() H.helper() end  -- Public API calls helpers

return Sllm
```

## Development Commands

```bash
make ci       # Run all checks (format, lint, test)
make format   # stylua + deno fmt
make lint     # luacheck
make test     # mini.test
make docs     # Generate doc/sllm.txt from doc/*.md (pandoc)
```

**Code style**: 2-space indent, single quotes, 120 char max, snake_case
functions, PascalCase modules.

## Adding Features

1. Add state to `H.state` (use nesting for logical grouping)
2. Create `H.domain_*` helper functions
3. Add `Sllm.*` public API if user-facing
4. Add keymap in `H.KEYMAP_DEFS` if needed
5. Add tests in `tests/`
6. Update README.md
7. Run `make ci`

## Guidelines

- **Architecture**: Use ModuleName + H pattern, prefix helpers by domain
- **State**: All state in `H.state`, never separate variables
- **Modes**: Templates ARE modes (native `llm` templates in `templates/`)
- **Testing**: Test public API only, not helpers
- **Philosophy**: Keep wrapper simple, delegate to `llm` CLI
- **No over-engineering**: Only make requested changes

## Documentation Conventions

- Docs are authored in `doc/*.md` and built to `doc/sllm.txt` via `pandoc` (vimdoc target) using a Lua filter.
- Try to do not use md tables they can not rendered very well in the vimdoc help generated from them
- Only top-level headings (H1) produce tags; subheadings render as bold text without tags to avoid tag bloat.
- After edits, run `make docs` (requires `pandoc`) and `:helptags doc`.
- Optional modeline is appended automatically: `vim:tw=78:ts=2:sw=2:et:ft=help:norl:`.
- Keep Lua annotations (`---@param`, `---@return`, etc.) for type clarity, but vimdoc generation now comes from Markdown, not mini.doc.
- Use regular comments (`--`) for `H.*` helpers; reserve `---` for public API docs when needed.
