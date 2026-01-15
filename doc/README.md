# sllm.nvim docs {#sllm-docs}

This folder contains the Markdown sources for the plugin documentation.

## Getting started (defaults)

1. Install the `llm` CLI (e.g., `brew install llm` or `pip install llm`).
2. Install an extension, for example `llm install llm-openrouter` or
   `llm install llm-anthropic`.
3. Set your API key with `llm keys set <provider>` (or an environment variable).
4. Install the plugin with your manager (lazy.nvim example):

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

The defaults ship with streaming chat, inline completion, history browsing,
context capture, and slash commands. Keymaps start with `<leader>s…` (ask,
model, mode, context, commands, history, toggle, cancel, complete).

## More guides

- Configuration and defaults: `doc/configure.md`
- Slash commands reference: `doc/slash_commands.md`
- Modes and templates: `doc/modes.md`
- Hooks (pre/post): `doc/hooks.md`
- LLM backend setup: `doc/backend_llm.md`
