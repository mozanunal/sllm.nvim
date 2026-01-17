# Configure sllm.nvim {#sllm-configure}

This guide covers all configuration options with examples.

## Default configuration

Call `setup()` with no arguments to use sensible defaults:

```lua
require('sllm').setup()
```

Or customize any option:

```lua
require('sllm').setup({
  -- Backend settings
  llm_cmd = 'llm',                    -- path to llm binary

  -- Model settings
  default_model = 'default',          -- model name or 'default' for llm's default
  default_mode = 'sllm_chat',         -- template to use on startup

  -- Behavior
  on_start_new_chat = true,           -- start fresh on plugin load
  reset_ctx_each_prompt = true,       -- clear context after each prompt
  online_enabled = false,             -- enable web search mode

  -- Limits
  history_max_entries = 1000,         -- max conversations in history picker
  chain_limit = 100,                  -- max tool calls per interaction

  -- Window
  window_type = 'vertical',           -- 'vertical', 'horizontal', or 'float'
  scroll_to_bottom = true,            -- auto-scroll to new content

  -- UI functions (integrate with your preferred plugins)
  pick_func = vim.ui.select,          -- picker function
  notify_func = vim.notify,           -- notification function
  input_func = vim.ui.input,          -- input prompt function

  -- Hooks (see hooks.md)
  pre_hooks = nil,
  post_hooks = nil,

  -- Keymaps (see below)
  keymaps = { ... },

  -- UI text customization
  ui = {
    show_usage = true,
    ask_llm_prompt = 'Prompt: ',
    add_url_prompt = 'URL: ',
    add_cmd_prompt = 'Command: ',
    markdown_prompt_header = '> Prompt:',
    markdown_response_header = '> Response',
    set_system_prompt = 'System Prompt: ',
  },
})
```

## Keymaps

Default keymaps all start with `<leader>s`:

```lua
keymaps = {
  ask = '<leader>ss',           -- open prompt and ask LLM
  select_model = '<leader>sm',  -- pick a model
  select_mode = '<leader>sM',   -- pick a template/mode
  add_context = '<leader>sa',   -- add file or selection to context
  commands = '<leader>sx',      -- open slash command picker
  new_chat = '<leader>sn',      -- start new chat
  cancel = '<leader>sc',        -- cancel running request
  toggle_buffer = '<leader>st', -- toggle LLM window
  history = '<leader>sh',       -- browse chat history
  copy_code = '<leader>sy',     -- copy last code block
  complete = '<leader><Tab>',   -- inline completion at cursor
}
```

**Customizing keymaps:**

```lua
-- Change specific keys
keymaps = {
  ask = '<leader>a',
  cancel = '<C-c>',
}

-- Disable a specific keymap
keymaps = {
  complete = false,  -- or nil
}

-- Disable all default keymaps
keymaps = false
```

When disabling defaults, set up your own mappings:

```lua
vim.keymap.set({ 'n', 'v' }, '<leader>a', require('sllm').ask_llm)
vim.keymap.set('n', '<leader>m', require('sllm').select_model)
```

## Window types

Control how the LLM buffer appears:

```lua
-- Split to the right (default)
window_type = 'vertical'

-- Split below
window_type = 'horizontal'

-- Floating window (centered, 70% of screen)
window_type = 'float'
```

## Context behavior

By default, context (files, snippets, tools) is cleared after each prompt. To
keep context across turns:

```lua
reset_ctx_each_prompt = false
```

This is useful when you want to keep discussing the same files without re-adding
them.

## Continuing conversations

By default, each Neovim session starts a new conversation. To continue the last
conversation from your llm history:

```lua
on_start_new_chat = false
```

## Integration with mini.nvim

If you have mini.pick and mini.notify installed, they're used automatically:

```lua
-- Explicit configuration (these are auto-detected)
pick_func = require('mini.pick').ui_select,
notify_func = require('mini.notify').make_notify(),
```

## Integration with other pickers

Use telescope, fzf-lua, or any picker that implements `vim.ui.select`:

```lua
-- Example with dressing.nvim (wraps vim.ui.select)
pick_func = vim.ui.select
```

## Model options

Set model-specific options at runtime with `/set-option` or programmatically:

```lua
-- In your config, set default options
-- (Note: these are passed to llm with -o flag)
```

At runtime:

- `/options` shows available options for the current model
- `/set-option` sets a key/value pair
- `/reset-options` clears all options

## Chain limit for agent mode

When using `sllm_agent` mode, the LLM can make multiple tool calls. Limit this
to prevent runaway sessions:

```lua
chain_limit = 100   -- max tool calls per interaction (default)
chain_limit = 10    -- more conservative
chain_limit = 500   -- for complex agentic tasks
```

## Example configurations

**Minimal (all defaults):**

```lua
require('sllm').setup()
```

**With custom model and window:**

```lua
require('sllm').setup({
  default_model = 'claude-3-5-sonnet',
  default_mode = 'sllm_agent',
  window_type = 'float',
})
```

**Power user with persistent context:**

```lua
require('sllm').setup({
  default_model = 'claude-3-5-sonnet',
  reset_ctx_each_prompt = false,
  on_start_new_chat = false,
  chain_limit = 200,
  keymaps = {
    ask = '<leader>a',
    commands = '<leader>/',
  },
  pre_hooks = {
    { command = 'git diff --cached', add_to_context = true },
  },
})
```

**Minimal keymaps (define your own):**

```lua
require('sllm').setup({
  keymaps = false,
})

local sllm = require('sllm')
vim.keymap.set({ 'n', 'v' }, '<leader>l', sllm.ask_llm)
vim.keymap.set('n', '<leader>L', sllm.toggle_llm_buffer)
```
