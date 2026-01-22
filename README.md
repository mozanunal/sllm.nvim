# sllm.nvim

[![CI](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/mozanunal/sllm.nvim?include_prereleases)](https://github.com/mozanunal/sllm.nvim/releases)

A lightweight Neovim wrapper for Simon Willison's
[`llm`](https://github.com/simonw/llm) CLI. Chat with LLMs, run agentic
workflows, and complete code without leaving your editor.

![workflow](https://github.com/user-attachments/assets/6df27581-520e-4027-a072-d65c49e5b598)

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

## Keymaps

Defaults use the `<leader>s` prefix (`<leader>ss` to ask). See [doc/configure.md](./doc/configure.md) for the full list and how to override.

## Modes (templates)

Templates configure the LLM's behavior. Defaults are described in [doc/modes.md](./doc/modes.md); switch with `<leader>sM` or `/template`.

## Slash commands

Press `<leader>sx` to open the slash command picker, or see [doc/slash_commands.md](./doc/slash_commands.md) for the full list (e.g., `/new`, `/model`, `/add-file`).

## Why sllm.nvim

- **Super easy customizable agentic modes** — Modes are just YAML files, tools are just Python functions
- **Explicit context control** — You decide what the LLM sees
- **Native llm integration** — Uses llm's templates, tools, and history
- **Async streaming** — Responses stream in real-time with loading indicator
- **Token tracking** — See usage and cost in the winbar
- **Minimal footprint** — Follows mini.nvim patterns, thin wrapper over llm

## Configuration

```lua
require('sllm').setup({
  default_model = 'claude-3-5-sonnet',  -- or 'default' for llm's default
  default_mode = 'sllm_chat',           -- template to use on startup
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
