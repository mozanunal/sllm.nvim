# sllm.nvim

[![CI](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/mozanunal/sllm.nvim?include_prereleases)](https://github.com/mozanunal/sllm.nvim/releases)

<img src="./assets/workflow.gif" alt="sllm.nvim Workflow"/>

**sllm.nvim** is a Neovim plugin that integrates Simon Willison’s [`llm`](https://github.com/simonw/llm) CLI directly into your editor.
Chat with large language models, stream responses in a scratch buffer, manage context files, switch models or tool integrations on the fly, and control everything asynchronously without leaving Neovim.

## Philosophy & Comparison

The landscape of AI plugins for Neovim is growing. To understand the philosophy behind `sllm.nvim` and see how it compares to other popular plugins, please read the [**PREFACE.md**](./PREFACE.md).

---

## Features

- **Interactive Chat**
  Send prompts to any installed LLM backend, streaming replies line by line.
- **Context Management**
  Add or reset files, URLs, shell command outputs, selections, diagnostics, installed LLM tools, or **on-the-fly Python functions** in the context so the model can reference your code, web content, command results, or issues.
- **Model and Tool Selection**
  Browse and pick from your installed `llm` models **and tools** interactively and add selected tools to your context.
- **On-the-fly Function Tools**
  Define Python functions as tools for the LLM directly from your current buffer or a visual selection.
- **Asynchronous & Non-blocking**
  Requests run in the background, so you can keep editing.
- **Split Buffer UI**
  Responses appear in a dedicated markdown buffer with wrap/linebreak enabled.
- **Token Usage Feedback**
  Displays request/response token usage and estimated cost after each prompt (when `show_usage` is enabled).

---

## Installation

### Prerequisites

1.  **Install the `llm` CLI**
    Follow instructions at https://github.com/simonw/llm
    e.g. `brew install llm` or `pip install llm`.
    > 💡 If `llm` is not in your system's `PATH`, you can set the full path in the configuration via the `llm_cmd` option.

2.  **Install one or more `llm` extensions**
    -   `llm install llm-openai`
    -   `llm install llm-openrouter`
    -   `llm install llm-gpt4all`
    …or any other plugin supported by `llm`.
    > 💡 The [`llm-openrouter`](https://github.com/simonw/llm-openrouter) extension gives access to over 300 models (some free) via [OpenRouter](https://openrouter.ai/).
    >
    > See all available LLM plugins for the `llm` CLI at [llm.datasette.io/plugins/directory](https://llm.datasette.io/en/stable/plugins/directory.html).

3.  **Configure your API key(s)**
    ```sh
    llm keys set openai
    # or for other services
    llm keys set openrouter
    ```
    or set environment variables like `OPENAI_API_KEY`.

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

Call `require("sllm").setup()` with an optional table of overrides:

```lua
require("sllm").setup({
  llm_cmd                  = "llm", -- command or path for the llm CLI
  default_model            = "gpt-4.1", -- default llm model (set to "default" to use llm's default model)
  show_usage               = true, -- append usage stats to responses
  on_start_new_chat        = true, -- start fresh chat on setup
  reset_ctx_each_prompt    = true, -- clear file context each ask
  window_type              = "vertical", -- Default. Options: "vertical", "horizontal", "float"
  -- function for item selection (like vim.ui.select)
  pick_func                = require("mini.pick").ui_select,
  -- function for notifications (like vim.notify)
  notify_func              = require("mini.notify").make_notify(),
  -- function for inputs (like vim.ui.input)
  input_func               = vim.ui.input,
  -- See the "Customizing Keymaps" section for more details
  keymaps = {
    -- Change a default keymap
    ask_llm = "<leader>a",
    -- Disable a default keymap
    add_url_to_ctx = false,
    -- Other keymaps will use their default values
  },
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `llm_cmd` | string | `"llm"` | Command or path for the `llm` CLI tool. |
| `default_model` | string | `"gpt-4.1"` | Model to use on startup |
| `show_usage` | boolean | `true` | Include token usage summary in responses. If `true`, you'll see details after each interaction. |
| `on_start_new_chat` | boolean | `true` | Begin with a fresh chat buffer on plugin setup |
| `reset_ctx_each_prompt` | boolean | `true` | Automatically clear file context after every prompt (if `true`) |
| `window_type` | string | `"vertical"` | Window style: `"vertical"`, `"horizontal"`, or `"float"`. |
| `pick_func` | function| `require('mini.pick').ui_select` | UI function for interactive model selection |
| `notify_func` | function| `require('mini.notify').make_notify()` | Notification function |
| `input_func` | function| `vim.ui.input` | Input prompt function. |
| `keymaps` | table/false | (see defaults) | A table of keybindings. Set any key to `false` or `nil` to disable it. Set the whole `keymaps` option to `false` to disable all defaults. |

## Keybindings & Commands

The following table lists the **default** keybindings. All of them can be changed or disabled in your `setup` configuration (see [Customizing Keymaps](#customizing-keymaps)).

| Keybind        | Keymap               | Mode  | Action                                                     |
|----------------|----------------------|-------|------------------------------------------------------------|
| `<leader>ss`   | `ask_llm`            | n,v   | Prompt the LLM with an input box                           |
| `<leader>sn`   | `new_chat`           | n,v   | Start a new chat (clears buffer)                           |
| `<leader>sc`   | `cancel`             | n,v   | Cancel current request                                     |
| `<leader>sf`   | `focus_llm_buffer`   | n,v   | Focus the LLM output buffer                                |
| `<leader>st`   | `toggle_llm_buffer`  | n,v   | Toggle LLM buffer visibility                               |
| `<leader>sm`   | `select_model`       | n,v   | Pick a different LLM model                                 |
| `<leader>sa`   | `add_file_to_ctx`    | n,v   | Add current file to context                                |
| `<leader>su`   | `add_url_to_ctx`     | n,v   | Add content of a URL to context                            |
| `<leader>sv`   | `add_sel_to_ctx`     | v     | Add visual selection to context                            |
| `<leader>sd`   | `add_diag_to_ctx`    | n,v   | Add diagnostics to context                                 |
| `<leader>sx`   | `add_cmd_out_to_ctx` | n,v   | Add shell command output to context                        |
| `<leader>sT`   | `add_tool_to_ctx`    | n,v   | Add an installed tool to context                           |
| `<leader>sF`   | `add_func_to_ctx`    | n,v   | Add Python function from buffer/selection as a tool        |
| `<leader>sr`   | `reset_context`      | n,v   | Reset/clear all context files                              |

---

### Customizing Keymaps

You have full control over the keybindings. Here are the common scenarios:

#### 1. Use the Defaults
If you are happy with the default keymaps, you don't need to pass a `keymaps` table at all. Just call `setup()` with no arguments or with other options.

#### 2. Change Some, Disable Others
To override specific keymaps, provide your new binding. To disable a keymap you don't use, set its value to `false` or `nil`. Any keymaps you don't specify will keep their default values.

```lua
-- In your setup() call:
require("sllm").setup({
  keymaps = {
    -- CHANGE: Use <leader>a for asking the LLM instead of <leader>ss
    ask_llm = "<leader>a",

    -- DISABLE: I don't use the "add URL" or "add tool" features
    add_url_to_ctx = false,
    add_tool_to_ctx = nil, -- `nil` also works for disabling
  },
})
```

#### 3. Disable All Default Keymaps
If you prefer to set up all keybindings manually, you can disable all defaults by passing `false` or an empty table `{}`.

```lua
-- In your setup() call:
require("sllm").setup({
  keymaps = false,
})

-- Now you can define your own from scratch
local sllm = require("sllm")
vim.keymap.set({"n", "v"}, "<leader>a", sllm.ask_llm, { desc = "Ask LLM [custom]" })
```
---

## Workflow Example

1. Open any file and press `<leader>ss`; type your prompt and hit Enter.
2. Add the entire file to context: `<leader>sa`.
3. Add only a visual selection: (Visual mode) `<leader>sv`.
4. Add diagnostics: `<leader>sd`.
5. Add the content of a URL: `<leader>su`.
6. Add a shell command output: `<leader>sx`.
7. **Add an installed tool to the context:** `<leader>sT`, then pick from the list.
8. **Define a tool from a Python function:** `<leader>sF` (use visual mode for a selection, or normal mode for the whole file).
9. Reset context: `<leader>sr`.
10. Switch models: `<leader>sm`.
11. Cancel a running request: `<leader>sc`.

### Visual Workflow

![sllm.nvim Workflow](./assets/workflow.png)

---

## Internals

- **Context Manager** (`sllm.context_manager`)
  Tracks a list of file paths, text snippets, tool names, **and function definitions** to include in subsequent prompts.
- **Backend** (`sllm.backend.llm`)
  Builds and executes the `llm` CLI command, optionally adding `-T <tool>` for each active tool or `--functions <py_function>` for ad-hoc functions.
- **Job Manager** (`sllm.job_manager`)
  Spawns a Neovim job for the CLI, streams stdout line-by-line.
- **UI** (`sllm.ui`)
  Creates and manages a scratch markdown buffer to display streaming output.
- **Utils** (`sllm.utils`)
  Helper functions for buffer/window checks, path utilities, and more.

---

## Contributions & Credits

- The core LLM interaction is powered by Simon Willison’s excellent [`llm`](https://github.com/simonw/llm) CLI.
- The user interface components (notifications, pickers) are provided by the versatile [echasnovski/mini.nvim](https://github.com/echasnovski/mini.nvim) library.
- `sllm.nvim` itself is created and maintained by **mozanunal**, focusing on integrating these tools smoothly into Neovim.

---

## License

Apache 2.0 — see [LICENSE](./LICENSE).
`llm` and its extensions are copyright Simon Willison.

