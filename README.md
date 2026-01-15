# sllm.nvim

[![CI](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/mozanunal/sllm.nvim?include_prereleases)](https://github.com/mozanunal/sllm.nvim/releases)

**sllm.nvim** is a lightweight Neovim wrapper around Simon Willison’s
[`llm`](https://github.com/simonw/llm) CLI. Chat, run agentic commands, and
complete code without leaving the editor.

![sllm.nvim Workflow](./assets/workflow.gif)

## Quick start

1. Install `llm` (brew, pipx, or pip) and at least one extension, for example
   `llm install llm-openrouter` or `llm install llm-anthropic`.
2. Set your API key with `llm keys set <provider>` or an environment variable.
3. Install the plugin (lazy.nvim example):

```lua
{
  'mozanunal/sllm.nvim',
  dependencies = {
    'echasnovski/mini.notify',
    'echasnovski/mini.pick',
  },
  config = function()
    require('sllm').setup()
  end,
}
```

Defaults include streaming chat, context management, history browsing, slash
commands, and inline completion. Templates are symlinked to your `llm` templates
directory on setup.

## Default keymaps (summary)

All prefixed with `<leader>s`:

- `ss` ask
- `sm` model picker
- `sM` mode picker
- `sa` add file or selection
- `sx` command picker (slash commands)
- `sn` new chat
- `sc` cancel
- `st` toggle buffer
- `sh` history
- `sy` copy last code block
- `<Tab>` completion

## Why sllm.nvim

- Explicit control over context, tools, and templates.
- Async streaming UI with token usage stats and winbar status.
- Native `llm` template and tool support (including agent mode).
- Minimal dependencies; mirrors mini.nvim patterns.

## Documentation

Full guides live in `doc/` and are Markdown-first:

- Getting started and links: `doc/README.md`
- Configuration and defaults: `doc/configure.md`
- Slash commands: `doc/slash_commands.md`
- Modes and templates: `doc/modes.md`
- Hooks: `doc/hooks.md`
- LLM backend setup: `doc/backend_llm.md`

## License

Apache 2.0 — see [LICENSE](./LICENSE).
