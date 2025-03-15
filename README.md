# sllm.nvim

**sllm.nvim** is a Neovim plugin that integrates Simon Willison’s [`llm`](https://github.com/simonw/llm) CLI directly into your editor.
Chat with large language models, stream responses in a scratch buffer, manage context files, switch models on the fly, and control everything asynchronously without leaving Neovim.

---

## Features

- **Interactive Chat**
  Send prompts to any installed LLM backend, stream replies line by line.
- **Context Management**
  Add or reset files in the context so the model can reference your source code.
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
  show_usage               = true,        -- append usage stats to responses
  on_start_new_chat        = true,        -- start fresh chat on setup
  reset_context_after_each_prompt = true, -- clear file context each ask
  pick_func                = require("mini.pick").launch,   -- model selector
  notify_func              = require("mini.notify").notify, -- notifications
  keymaps = {
    ask_llm           = "<leader>ss",  -- prompt the LLM
    new_chat          = "<leader>sn",  -- clear chat buffer
    cancel            = "<leader>sc",  -- cancel ongoing request
    focus_llm_buffer  = "<leader>sf",  -- jump to LLM buffer
    toggle_llm_buffer = "<leader>st",  -- show/hide buffer
    select_model      = "<leader>sm",  -- choose a model
    add_file_to_context = "<leader>sa",-- add current file to context
    reset_context     = "<leader>sr",  -- clear all context
  },
})
```

| Option                          | Type    | Default     | Description                                                      |
|---------------------------------|---------|-------------|------------------------------------------------------------------|
| `default_model`                 | string  | `"gpt-4.1"` | Model to use on startup                                          |
| `show_usage`                    | boolean | `true`      | Include token usage summary in responses                         |
| `on_start_new_chat`             | boolean | `true`      | Begin with a fresh chat buffer on plugin setup                   |
| `reset_context_after_each_prompt` | boolean | `true`    | Automatically clear file context after every prompt (if `true`) |
| `pick_func`                     | function| `mini.pick` | UI function for interactive model selection                     |
| `notify_func`                   | function| `mini.notify` | Notification function                                           |
| `keymaps`                       | table   | (see above) | Custom keybindings                                              |

---

## Keybindings & Commands

| Keymap         | Mode | Action                             |
|----------------|------|------------------------------------|
| `<leader>ss`   | n    | Prompt the LLM with an input box  |
| `<leader>sn`   | n    | Start a new chat (clears buffer)  |
| `<leader>sc`   | n    | Cancel current request            |
| `<leader>sf`   | n    | Focus the LLM output buffer       |
| `<leader>st`   | n    | Toggle LLM buffer visibility      |
| `<leader>sm`   | n    | Pick a different LLM model        |
| `<leader>sa`   | n    | Add current file to context       |
| `<leader>sr`   | n    | Reset/clear all context files     |

---

## Workflow Example

1. Open any file and press `<leader>ss`.
2. Type your prompt and hit Enter. The LLM reply streams into a side buffer.
3. To include the current file in context for future prompts, press `<leader>sa`.
4. Reset the entire context with `<leader>sr`.
5. Switch models interactively with `<leader>sm`.
6. Cancel a running request with `<leader>sc`.

---

## Internals

- **Context Manager** (`sllm.context_manager`)
  Tracks a list of file paths to include in subsequent prompts.
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

