# sllm.nvim docs {#sllm-docs}

A lightweight Neovim wrapper for Simon Willison's
[`llm`](https://llm.datasette.io/) CLI. Chat with LLMs, run agentic workflows,
and complete code without leaving your editor.

## Features

- **Streaming chat** with markdown rendering and syntax highlighting
- **Context management** for files, selections, URLs, diagnostics, and command
  output
- **Agentic mode** with Python function tools (bash, read, write, edit, grep)
- **Template/mode system** for different workflows (chat, review, agent,
  complete)
- **History browsing** to continue past conversations
- **Slash commands** for quick actions
- **Inline completion** at cursor position
- **Token usage stats** and cost tracking in the winbar

## Quick start

**1. Install the llm CLI:**

```bash
brew install llm        # macOS
pipx install llm        # or pip install llm
```

**2. Install a provider extension:**

```bash
llm install llm-openrouter   # many models via OpenRouter
llm install llm-anthropic    # Claude models
llm install llm-openai       # OpenAI models
```

**3. Set your API key:**

```bash
llm keys set openrouter   # or: export OPENROUTER_KEY=...
```

**4. Install the plugin (lazy.nvim):**

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

That's it. Press `<leader>ss` to start chatting.

## Keymaps

Defaults use the `<leader>s` prefix (`<leader>ss` to ask). See
`doc/configure.md` for the full list and how to override.

## Templates (modes)

Templates configure system prompts and tools. The defaults are documented in
`doc/modes.md`; switch with `<leader>sM` or `/template`.

## Slash commands

Open the command picker with `<leader>sx` (fuzzy action picker), or type
`/command` directly (e.g., `/new`, `/model`, `/add-file`). See
`doc/slash_commands.md` for the full list.

## Documentation index

- **configure.md** - Full configuration reference and examples
- **slash_commands.md** - All slash commands with usage
- **modes.md** - Templates and custom mode creation
- **hooks.md** - Pre/post hooks for automation
- **backend_llm.md** - LLM CLI setup and extensions
- **api.md** - Public Lua API reference
- **development_guide.md** - Contributing and architecture
