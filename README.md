# sllm.nvim

**sllm.nvim** is a Neovim plugin that integrates Simon Willison’s [`llm`](https://github.com/simonw/llm) CLI directly into your editor.
Chat with large language models, stream responses in a scratch buffer, manage context files, switch models on the fly, and control everything asynchronously without leaving Neovim.

---

## Features

- **Interactive Chat**
  Send prompts to any installed LLM backend, stream replies line by line.
- **Context Management**
  Add or reset files, selections, or diagnostics in the context so the model can reference your source code or issues.
- **Model Selection**
  Browse and pick from your installed llm models interactively.
- **Asynchronous & Non-blocking**
  Requests run in the background, so you can keep editing.
- **Split Buffer UI**
  Responses appear in a dedicated markdown buffer with wrap/linebreak enabled.

---

## Installation

### Prerequisites

1. **Install the `llm` CLI**
   Follow instructions at https://github.com/simonw/llm
   e.g. `brew install llm` or `pip install llm`.

2. **Install one or more llm extensions**
   - `llm install llm-openai`
   - `llm install llm-openrouter`
   - `llm install llm-gpt4all`
   …or any other plugin supported by `llm`.

3. **Configure your API key**
   ```sh
   llm keys set openai
   ```
   or set `OPENAI_API_KEY` in your environment.

---

### Plugin Managers

#### lazy.nvim

```lua
{
  "mozanunal/sllm.nvim",
  dependencies = {
    "echasnovski/mini.notify",
    "echasnovski/mini.pick",
  },
  config = function()
    require("sllm").setup({
      -- your custom options here
    })
  end,
}
```

#### packer.nvim

```lua
use({
  "mozanunal/sllm.nvim",
  requires = { "echasnovski/mini.notify", "echasnovski/mini.pick" },
  config = function()
    require("sllm").setup({
      -- your custom options here
    })
  end,
})
```

---

## Configuration

Call `require("sllm").setup()` with an optional table:

```lua
require("sllm").setup({
  default_model            = "gpt-4.1",  -- default llm model
  show_usage               = true,       -- append usage stats to responses
  on_start_new_chat        = true,       -- start fresh chat on setup
  reset_context_after_each_prompt = true,  -- clear file context each ask
  pick_func                = require("mini.pick").ui_select, -- function for item selection (like vim.ui.select)
  notify_func              = require("mini.notify").make_notify(), -- function for notifications (like vim.notify)
  keymaps = {
    ask_llm                  = "<leader>ss",  -- prompt the LLM
    new_chat                 = "<leader>sn",  -- clear chat buffer
    cancel                   = "<leader>sc",  -- cancel ongoing request
    focus_llm_buffer         = "<leader>sf",  -- jump to LLM buffer
    toggle_llm_buffer        = "<leader>st",  -- show/hide buffer
    select_model             = "<leader>sm",  -- choose a model
    add_file_to_ctx          = "<leader>sa",  -- add current file to context
    add_sel_to_ctx           = "<leader>sv",  -- add visual selection to context
    add_diagnostics_to_ctx   = "<leader>sd",  -- add diagnostics to context
    reset_context            = "<leader>sr",  -- clear all context
  },
})
```

| Option                          | Type    | Default     | Description                                                      |
|---------------------------------|---------|-------------|------------------------------------------------------------------|
| `default_model`                 | string  | `"gpt-4.1"`                              | Model to use on startup                                          |
| `show_usage`                    | boolean | `true`                                   | Include token usage summary in responses                         |
| `on_start_new_chat`             | boolean | `true`                                   | Begin with a fresh chat buffer on plugin setup                   |
| `reset_context_after_each_prompt` | boolean | `true`                                 | Automatically clear file context after every prompt (if `true`) |
| `pick_func`                     | function| `require('mini.pick').ui_select`         | UI function for interactive model selection                     |
| `notify_func`                   | function| `require('mini.notify').make_notify()`   | Notification function                                           |
| `keymaps`                       | table   | (see default config example)             | Custom keybindings                                              |

---

## Keybindings & Commands

| Keymap         | Mode  | Action                             |
|----------------|-------|------------------------------------|
| `<leader>ss`   | n,v   | Prompt the LLM with an input box  |
| `<leader>sn`   | n,v   | Start a new chat (clears buffer)  |
| `<leader>sc`   | n,v   | Cancel current request            |
| `<leader>sf`   | n,v   | Focus the LLM output buffer       |
| `<leader>st`   | n,v   | Toggle LLM buffer visibility      |
| `<leader>sm`   | n,v   | Pick a different LLM model        |
| `<leader>sa`   | n,v   | Add current file to context       |
| `<leader>sv`   | v     | Add visual selection to context   |
| `<leader>sd`   | n,v   | Add diagnostics to context      |
| `<leader>sr`   | n,v   | Reset/clear all context files     |

---

## Workflow Example

1. Open any file and press `<leader>ss` (Normal or Visual mode).
2. Type your prompt and hit Enter. The LLM reply streams into a side buffer.
3. To include the entire content of the current file in context, press `<leader>sa`.
4. Select some text in Visual mode and press `<leader>sv` to add only the selection to the context.
5. If your buffer has diagnostics (e.g., from linters/LSPs), press `<leader>sd` to add them to the context.
6. Reset the entire context with `<leader>sr`.
7. Switch models interactively with `<leader>sm`.
8. Cancel a running request with `<leader>sc`.

---

## Internals

- **Context Manager** (`sllm.context_manager`)
  Tracks a list of file paths and text snippets to include in subsequent prompts.
- **Backend** (`sllm.backend.llm`)
  Builds the CLI command `llm -m <model> -f <file> … <prompt>`.
- **Job Manager** (`sllm.job_manager`)
  Spawns a Neovim job for the CLI, streams stdout line-by-line.
- **UI** (`sllm.ui`)
  Creates and manages a scratch markdown buffer to display streaming output.
- **Utils** (`sllm.utils`)
  Helper functions for buffer/window checks, path utilities, and more.

---

## Contributions & Credits

- Powered by Simon Willison’s [`llm`](https://github.com/simonw/llm) CLI.
- UI and picker powered by [echasnovski/mini.nvim](https://github.com/echasnovski/mini.nvim).
- Created and maintained by **mozanunal**.

---

## License

Apache 2.0 — see [LICENSE](./LICENSE).
`llm` and its extensions are copyright Simon Willison.
