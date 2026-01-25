# API reference {#sllm-api}

This reference documents the public Lua API for sllm.nvim.

## Setup

### Sllm.setup(config)

Initialize the plugin with optional configuration.

```lua
require('sllm').setup()        -- use defaults
require('sllm').setup({...})   -- with custom config
```

See `configure.md` for all options.

## Chat functions

### Sllm.ask_llm()

Open the prompt and send a query to the LLM. In visual mode, the selection is
automatically added to context.

```lua
require('sllm').ask_llm()
```

### Sllm.new_chat()

Start a new chat session. Clears the buffer, resets conversation state, and
resets token usage stats.

```lua
require('sllm').new_chat()
```

### Sllm.cancel()

Cancel the currently running LLM request.

```lua
require('sllm').cancel()
```

### Sllm.browse_history()

Open the history picker to browse and continue past conversations.

```lua
require('sllm').browse_history()
```

## Context functions

### Sllm.add_context()

Smart context add: adds file in normal mode, selection in visual mode.

```lua
require('sllm').add_context()
```

### Sllm.add_file_to_ctx()

Add the current buffer's file path to context.

```lua
require('sllm').add_file_to_ctx()
```

### Sllm.add_sel_to_ctx()

Add the current visual selection as a code snippet.

```lua
require('sllm').add_sel_to_ctx()
```

### Sllm.add_url_to_ctx()

Prompt for a URL and add it to context.

```lua
require('sllm').add_url_to_ctx()
```

### Sllm.add_diag_to_ctx()

Add LSP diagnostics from the current buffer to context.

```lua
require('sllm').add_diag_to_ctx()
```

### Sllm.add_cmd_out_to_ctx()

Prompt for a shell command, run it, and add the output to context.

```lua
require('sllm').add_cmd_out_to_ctx()
```

### Sllm.add_tool_to_ctx()

Open picker to select an llm tool and add it to the session.

```lua
require('sllm').add_tool_to_ctx()
```

### Sllm.add_func_to_ctx()

Add a Python function to context. Uses visual selection if available, otherwise
uses the entire buffer.

```lua
require('sllm').add_func_to_ctx()
```

### Sllm.reset_context()

Clear all context (files, snippets, tools, functions).

```lua
require('sllm').reset_context()
```

## Model and mode functions

### Sllm.select_model()

Open picker to select an LLM model.

```lua
require('sllm').select_model()
```

### Sllm.select_mode()

Open picker to select a template/mode. Alias for `select_template()`.

```lua
require('sllm').select_mode()
```

### Sllm.select_template()

Open picker to select a template.

```lua
require('sllm').select_template()
```

### Sllm.edit_template()

Open the active template file for editing in Neovim.

```lua
require('sllm').edit_template()
```

### Sllm.show_model_options()

Show available options for the current model (runs `llm models --options`).

```lua
require('sllm').show_model_options()
```

### Sllm.set_system_prompt()

Prompt to set or update the system prompt.

```lua
require('sllm').set_system_prompt()
```

### Sllm.set_model_option()

Prompt to set a model option (key/value pair).

```lua
require('sllm').set_model_option()
```

### Sllm.reset_model_options()

Clear all model options set during the session.

```lua
require('sllm').reset_model_options()
```

### Sllm.toggle_online()

Toggle online/web search mode.

```lua
require('sllm').toggle_online()
```

### Sllm.is_online_enabled()

Return whether online mode is currently enabled.

```lua
local enabled = require('sllm').is_online_enabled()
```

## UI functions

### Sllm.toggle_llm_buffer()

Toggle visibility of the LLM window.

```lua
require('sllm').toggle_llm_buffer()
```

### Sllm.focus_llm_buffer()

Focus the LLM window, creating it if needed.

```lua
require('sllm').focus_llm_buffer()
```

## Copy functions

### Sllm.copy_last_code_block()

Copy the last code block from the response to clipboard.

```lua
require('sllm').copy_last_code_block()
```

### Sllm.copy_first_code_block()

Copy the first code block from the response to clipboard.

```lua
require('sllm').copy_first_code_block()
```

### Sllm.copy_last_response()

Copy the entire last response to clipboard.

```lua
require('sllm').copy_last_response()
```

## Completion

### Sllm.complete_code()

Trigger inline code completion at the cursor position.

```lua
require('sllm').complete_code()
```

## Command runner

### Sllm.run_command(cmd)

Execute a slash command by name, or open the picker if no command given.

```lua
require('sllm').run_command()       -- open picker
require('sllm').run_command('new')  -- execute /new
require('sllm').run_command('model')-- execute /model
```

## Configuration access

### Sllm.config

The current configuration table, after merging with defaults.

```lua
local config = require('sllm').config
print(config.default_model)
```

## Example: Custom keymaps

```lua
local sllm = require('sllm')

-- Disable default keymaps
sllm.setup({ keymaps = false })

-- Set up custom keymaps
vim.keymap.set({ 'n', 'v' }, '<leader>a', sllm.ask_llm, { desc = 'Ask LLM' })
vim.keymap.set('n', '<leader>A', sllm.new_chat, { desc = 'New chat' })
vim.keymap.set('n', '<leader>m', sllm.select_model, { desc = 'Pick model' })
vim.keymap.set({ 'n', 'v' }, '<leader>c', sllm.add_context, { desc = 'Add context' })
vim.keymap.set('n', '<leader>/', sllm.run_command, { desc = 'Commands' })
vim.keymap.set('n', '<leader>t', sllm.toggle_llm_buffer, { desc = 'Toggle LLM' })
vim.keymap.set('n', '<leader>h', sllm.browse_history, { desc = 'History' })
vim.keymap.set('n', '<leader>y', sllm.copy_last_code_block, { desc = 'Copy code' })
vim.keymap.set('i', '<C-Space>', sllm.complete_code, { desc = 'Complete' })
```

## Example: Programmatic usage

```lua
local sllm = require('sllm')

-- Add files programmatically before asking
sllm.add_file_to_ctx()  -- adds current buffer

-- Switch to agent mode
-- (This requires the mode picker, so call select_mode() or set default_mode)

-- Check if a request is running
-- (Internal state, not directly exposed, but cancel() is safe to call)
sllm.cancel()  -- no-op if nothing running
```
