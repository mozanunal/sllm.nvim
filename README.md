# sllm.nvim

[![CI](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/mozanunal/sllm.nvim?include_prereleases)](https://github.com/mozanunal/sllm.nvim/releases)

A lightweight Neovim wrapper for Simon Willison's
[`llm`](https://github.com/simonw/llm) CLI. Chat with LLMs, run agentic
workflows, and complete code without leaving your editor.

![sllm.nvim Workflow](./assets/workflow.gif)

## Features

- **Streaming chat** with markdown rendering and syntax highlighting
- **Context management** for files, selections, URLs, diagnostics, and shell
  output
- **Agentic mode** with Python function tools (bash, read, write, edit, grep)
- **Template/mode system** for different workflows (chat, review, agent,
  complete)
- **History browsing** to continue past conversations
- **Slash commands** for quick actions (`/new`, `/model`, `/add-file`, etc.)
- **Inline completion** at cursor position
- **Token usage stats** and cost tracking in the winbar

## Quick start

**1. Install the llm CLI:**

```bash
brew install llm        # macOS
pipx install llm        # or pip install llm
```

**2. Install a provider and set your API key:**

```bash
llm install llm-openrouter && llm keys set openrouter
# or: llm install llm-anthropic && llm keys set anthropic
```

**3. Install the plugin (lazy.nvim):**

```lua
{
  'mozanunal/sllm.nvim',
  dependencies = {
    'echasnovski/mini.notify',  -- optional, nicer notifications
    'echasnovski/mini.pick',    -- optional, better picker UI
  },
  config = function()
    require('sllm').setup()
  end,
}
```

Press `<leader>ss` to start chatting.

## Default keymaps

All keymaps work in both normal and visual mode:

- `<leader>ss` — Ask the LLM (opens prompt)
- `<leader>sm` — Select model
- `<leader>sM` — Select mode/template
- `<leader>sa` — Add file (normal) or selection (visual) to context
- `<leader>sx` — Open command picker
- `<leader>sn` — Start new chat
- `<leader>sc` — Cancel current request
- `<leader>st` — Toggle LLM buffer
- `<leader>sh` — Browse chat history
- `<leader>sy` — Copy last code block
- `<leader><Tab>` — Complete code at cursor

## Modes (templates)

Templates configure the LLM's behavior. Four defaults are included:

- **sllm_chat** — General chat with markdown responses
- **sllm_read** — Code review with read-only file access (list, read, grep,
  glob)
- **sllm_agent** — Agentic mode with full tool access (bash, read, write, edit,
  grep, glob, patch, webfetch)
- **sllm_complete** — Inline completion (used by `<leader><Tab>`)

Switch modes with `<leader>sM` or `/template`.

## Slash commands

Type `/` at the prompt to open the command picker, or use commands directly:

- `/new` — Start new chat
- `/history` — Browse past conversations
- `/add-file` — Add current file to context
- `/add-selection` — Add visual selection
- `/add-diagnostics` — Add LSP diagnostics
- `/model` — Switch model
- `/template` — Switch template
- `/online` — Toggle web search mode
- `/copy-code` — Copy last code block
- `/clear-context` — Reset all context

See [doc/slash_commands.md](./doc/slash_commands.md) for the full list.

## Why sllm.nvim

- **Explicit context control** — You decide what the LLM sees
- **Native llm integration** — Uses llm's templates, tools, and history
- **Async streaming** — Responses stream in real-time with loading indicator
- **Token tracking** — See usage and cost in the winbar
- **Minimal footprint** — Follows mini.nvim patterns, thin wrapper over llm

## Configuration

```lua
require('sllm').setup({
  default_model = 'claude-3-5-sonnet',  -- or 'default' for llm's default
  default_mode = 'sllm_agent',          -- template to use on startup
  window_type = 'float',                -- 'vertical', 'horizontal', or 'float'
  reset_ctx_each_prompt = false,        -- keep context across turns
  keymaps = {
    ask = '<leader>a',                  -- customize keymaps
  },
})
```

See [doc/configure.md](./doc/configure.md) for all options.

## Documentation

Full guides in `doc/`:

- [README.md](./doc/README.md) — Overview and quick start
- [configure.md](./doc/configure.md) — Configuration reference
- [slash_commands.md](./doc/slash_commands.md) — All slash commands
- [modes.md](./doc/modes.md) — Templates and custom modes
- [hooks.md](./doc/hooks.md) — Pre/post hooks
- [backend_llm.md](./doc/backend_llm.md) — LLM CLI setup
- [api.md](./doc/api.md) — Public Lua API

Or in Neovim: `:help sllm`

## License

Apache 2.0 — see [LICENSE](./LICENSE).
