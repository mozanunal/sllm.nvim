# sllm.nvim docs {#sllm-docs}

A lightweight Neovim wrapper for Simon Willison's
[`llm`](https://llm.datasette.io/) CLI. Chat with LLMs, run agentic workflows,
and complete code without leaving your editor.

## Features

- **Streaming chat** with markdown rendering and syntax highlighting
- **Context management** for files, selections, URLs, diagnostics, and command
  output
- **Agentic mode** with Python function tools (read, write, edit, grep, bash)
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

## Default keymaps

All keymaps work in both normal and visual mode:

- `<leader>ss` - Ask the LLM (opens prompt)
- `<leader>sm` - Select model
- `<leader>sM` - Select mode/template
- `<leader>sa` - Add file (normal) or selection (visual) to context
- `<leader>sx` - Open command picker (slash commands)
- `<leader>sn` - Start new chat
- `<leader>sc` - Cancel current request
- `<leader>st` - Toggle LLM buffer
- `<leader>sh` - Browse chat history
- `<leader>sy` - Copy last code block
- `<leader><Tab>` - Complete code at cursor

## Winbar status

The LLM buffer displays a winbar showing:

- Loading spinner during requests
- Current model name (e.g., `claude-3-5-sonnet`)
- Active mode/template in brackets (e.g., `[sllm_chat]`)
- Online indicator when web mode is enabled
- Token usage: input tokens, output tokens, and cost

## Shipped templates (modes)

Templates configure the LLM's behavior. Four defaults are installed:

- **sllm_chat** - General chat with markdown responses
- **sllm_read** - Code review with read-only file access
- **sllm_agent** - Agentic mode with bash, read, write, edit, grep tools
- **sllm_complete** - Inline completion (used by `<leader><Tab>`)

Switch modes with `<leader>sM` or `/template`.

## Documentation index

- **configure.md** - Full configuration reference and examples
- **slash_commands.md** - All slash commands with usage
- **modes.md** - Templates and custom mode creation
- **hooks.md** - Pre/post hooks for automation
- **backend_llm.md** - LLM CLI setup and extensions
- **api.md** - Public Lua API reference
- **development_guide.md** - Contributing and architecture
