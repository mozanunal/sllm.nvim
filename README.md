# sllm.nvim

[![CI](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/mozanunal/sllm.nvim/actions/workflows/ci.yml)
[![GitHub release](https://img.shields.io/github/v/release/mozanunal/sllm.nvim?include_prereleases)](https://github.com/mozanunal/sllm.nvim/releases)

<img src="./assets/workflow.gif" alt="sllm.nvim Workflow"/>

**sllm.nvim** is a Neovim plugin that integrates Simon Willison’s
[`llm`](https://github.com/simonw/llm) CLI directly into your editor. Chat with
large language models, stream responses in a scratch buffer, manage context
files, switch models or tool integrations on the fly, and control everything
asynchronously without leaving Neovim.

## Philosophy & Comparison

The landscape of AI plugins for Neovim is growing. To understand the philosophy
behind `sllm.nvim` and see how it compares to other popular plugins, please read
the [**PREFACE.md**](./PREFACE.md).

---

## Features

- **Interactive Chat** Send prompts to any installed LLM backend, streaming
  replies line by line.
- **Code Completion** Press `<leader><Tab>` to complete code at cursor position.
  Automatically includes current file context and inserts completion inline.
  Shows a loading indicator while processing.
- **History Navigation** Browse and load previous conversations using
  `llm logs`. View up to 1000 recent conversation threads (configurable) and
  continue chatting from any point.
- **Context Management** Add or reset files, URLs, shell command outputs,
  selections, diagnostics, installed LLM tools, or **on-the-fly Python
  functions** in the context so the model can reference your code, web content,
  command results, or issues.
- **Model and Tool Selection** Browse and pick from your installed `llm` models
  **and tools** interactively and add selected tools to your context.
- **On-the-fly Function Tools** Define Python functions as tools for the LLM
  directly from your current buffer or a visual selection.
- **Asynchronous & Non-blocking** Requests run in the background, so you can
  keep editing.
- **Split Buffer UI** Responses appear in a dedicated markdown buffer with
  wrap/linebreak enabled.
- **Token Usage Feedback** Displays request/response token usage and estimated
  cost after each prompt (when `show_usage` is enabled).
- **Code Block Extraction** Copy the first, last, or entire response from the
  LLM buffer to clipboard without focusing on it.

---

## Installation

### Prerequisites

1. **Install the `llm` CLI** Follow instructions at
   https://github.com/simonw/llm e.g. `brew install llm` or `pip install llm`.

   > 💡 If `llm` is not in your system's `PATH`, you can set the full path in
   > the configuration via `backend_config = { cmd = "/path/to/llm" }`.

2. **Install one or more `llm` extensions**
   - `llm install llm-openai`
   - `llm install llm-openrouter`
   - `llm install llm-gpt4all` …or any other plugin supported by `llm`.
     > 💡 The [`llm-openrouter`](https://github.com/simonw/llm-openrouter)
     > extension gives access to over 300 models (some free) via
     > [OpenRouter](https://openrouter.ai/).
     >
     > See all available LLM plugins for the `llm` CLI at
     > [llm.datasette.io/plugins/directory](https://llm.datasette.io/en/stable/plugins/directory.html).

3. **Configure your API key(s)**
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
  -- optional: will use vim.notify and vim.ui.select as fallback
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
  -- optional: will use vim.notify and vim.ui.select as fallback
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
  backend_config           = { cmd = "llm" }, -- backend settings (cmd = llm CLI path)
  -- model to use on startup. This setting uses the default model set for the llm CLI
  default_model            = "default",
  -- template/mode to use on startup (see "Templates & Modes" section)
  default_mode             = "sllm_chat",
  on_start_new_chat        = true, -- start fresh chat on setup
  reset_ctx_each_prompt    = true, -- clear file context each ask
  window_type              = "vertical", -- Default. Options: "vertical", "horizontal", "float"
  scroll_to_bottom         = true, -- whether to keep the cursor at the bottom of the LLM window
  -- function for item selection (like vim.ui.select)
  pick_func                = require("mini.pick").ui_select,
  -- function for notifications (like vim.notify)
  notify_func              = require("mini.notify").make_notify(),
  -- function for inputs (like vim.ui.input)
  input_func               = vim.ui.input,
  -- See the "Customizing Keymaps" section for more details
  keymaps = {
    -- Change a default keymap
    ask = "<leader>a",
    -- Disable a default keymap
    add_context_extra = false,
    -- Other keymaps will use their default values
  },
  -- Maximum number of history entries to fetch (default: 1000)
  history_max_entries = 1000,
  -- See the "Pre-Hooks and Post-Hooks" section for more details
  pre_hooks = {
    -- Example: automatically include git diff in context
    { command = "git diff HEAD", add_to_context = true },
  },
  post_hooks = {
    -- Example: log completion time
    { command = "date >> ~/.sllm_history.log" },
  },
  -- See the "Customizing the UI" section for more details
  ui = {
    show_usage = true, -- append usage stats to responses
    -- Text displayed above the LLM response
    markdown_prompt_header = '# 󰄛',
    -- Prompt displayed by 'ask'
    ask_llm_prompt = ' 󰄛  > ',
    -- Other UI elements will use their default values
  },
})
```

| Option                  | Type              | Default                                | Description                                                                                                                               |
| ----------------------- | ----------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `backend_config`        | table             | `{ cmd = "llm" }`                      | Backend settings. Use `cmd` to specify the path to the `llm` CLI.                                                                         |
| `default_model`         | string            | `"default"`                            | Model to use on startup. If "default", uses the default model set for the `llm` CLI.                                                      |
| `default_mode`          | string            | `"sllm_chat"`                          | Template/mode to use on startup. See "Templates & Modes" section.                                                                         |
| `on_start_new_chat`     | boolean           | `true`                                 | Begin with a fresh chat buffer on plugin setup                                                                                            |
| `reset_ctx_each_prompt` | boolean           | `true`                                 | Automatically clear file context after every prompt (if `true`)                                                                           |
| `window_type`           | string            | `"vertical"`                           | Window style: `"vertical"`, `"horizontal"`, or `"float"`.                                                                                 |
| `scroll_to_bottom`      | boolean           | `true`                                 | Whether to keep the cursor at the bottom of the LLM window.                                                                               |
| `pick_func`             | function          | `require('mini.pick').ui_select`       | UI function for interactive model selection                                                                                               |
| `notify_func`           | function          | `require('mini.notify').make_notify()` | Notification function                                                                                                                     |
| `input_func`            | function          | `vim.ui.input`                         | Input prompt function.                                                                                                                    |
| `online_enabled`        | boolean           | `false`                                | Enable online/web mode by default (shows 🌐 in status bar).                                                                               |
| `history_max_entries`   | integer           | `1000`                                 | Maximum number of history log entries to fetch when browsing conversations. Increase for more history, decrease for faster loading.       |
| `keymaps`               | table/false       | (see defaults)                         | A table of keybindings. Set any key to `false` or `nil` to disable it. Set the whole `keymaps` option to `false` to disable all defaults. |
| `ui`                    | table             | (see defaults)                         | UI settings including `show_usage` (token stats) and prompt text.                                                                         |

## Keybindings & Commands

The following table lists the **default** keybindings (12 total). All of them
can be changed or disabled in your `setup` configuration (see
[Customizing Keymaps](#customizing-keymaps)).

| Keybind         | Keymap              | Mode | Action                                             |
| --------------- | ------------------- | ---- | -------------------------------------------------- |
| `<leader>ss`    | `ask`               | n,v  | Prompt the LLM with an input box                   |
| `<leader>sm`    | `select_model`      | n,v  | Pick a different LLM model                         |
| `<leader>sM`    | `select_mode`       | n,v  | Switch mode/template (sllm_chat, sllm_agent, etc.) |
| `<leader>sa`    | `add_context`       | n,v  | Add file (normal) or selection (visual) to context |
| `<leader>sA`    | `add_context_extra` | n,v  | Picker for url/diag/cmd/tool/func context          |
| `<leader>sn`    | `new_chat`          | n,v  | Start a new chat (clears buffer)                   |
| `<leader>sc`    | `cancel`            | n,v  | Cancel current request                             |
| `<leader>st`    | `toggle_buffer`     | n,v  | Toggle LLM buffer visibility                       |
| `<leader>sW`    | `toggle_online`     | n,v  | Toggle online/web mode (shows 🌐 in status)        |
| `<leader>sh`    | `history`           | n,v  | Browse and continue previous conversations         |
| `<leader>sy`    | `copy_code`         | n,v  | Copy last code block from response to clipboard    |
| `<leader><Tab>` | `complete`          | n    | Inline code completion at cursor                   |

---

## Templates & Modes

sllm.nvim uses native `llm` templates as modes. The plugin ships with four
default templates that are automatically symlinked to your llm templates
directory on setup:

| Template        | Description                                      |
| --------------- | ------------------------------------------------ |
| `sllm_chat`     | Simple conversation, no tools                    |
| `sllm_read`     | Code review with read-only file tools            |
| `sllm_agent`    | Full agentic mode with bash, edit, write tools   |
| `sllm_complete` | Inline code completion (used by `<leader><Tab>`) |

### Switching Modes

Press `<leader>sM` to switch between templates/modes. The current mode is
displayed in the winbar: `sllm.nvim | Model: gpt-4o [sllm_agent]`

### Customizing Templates

Templates are standard `llm` YAML files. You can:

1. **Edit existing templates:**
   ```bash
   llm templates edit sllm_agent
   ```

2. **Create custom templates:**
   ```bash
   cp ~/.config/io.datasette.llm/templates/sllm_read.yaml ~/.config/io.datasette.llm/templates/my_reviewer.yaml
   llm templates edit my_reviewer
   ```

3. **View template contents:**
   ```bash
   llm templates show sllm_agent
   ```

Custom templates appear in the mode picker alongside the defaults.

For more information on llm templates:
https://llm.datasette.io/en/stable/templates.html

---

### Customizing Keymaps

You have full control over the keybindings. Here are the common scenarios:

#### 1. Use the Defaults

If you are happy with the default keymaps, you don't need to pass a `keymaps`
table at all. Just call `setup()` with no arguments or with other options.

#### 2. Change Some, Disable Others

To override specific keymaps, provide your new binding. To disable a keymap you
don't use, set its value to `false` or `nil`. Any keymaps you don't specify will
keep their default values.

```lua
-- In your setup() call:
require("sllm").setup({
  keymaps = {
    -- CHANGE: Use <leader>a for asking the LLM instead of <leader>ss
    ask = "<leader>a",

    -- DISABLE: I don't use the extra context picker
    add_context_extra = false,
  },
})
```

#### 3. Disable All Default Keymaps

If you prefer to set up all keybindings manually, you can disable all defaults
by passing `false` or an empty table `{}`.

```lua
-- In your setup() call:
require("sllm").setup({
  keymaps = false,
})

-- Now you can define your own from scratch
local sllm = require("sllm")
vim.keymap.set({"n", "v"}, "<leader>a", sllm.ask, { desc = "Ask LLM [custom]" })
```

### Customizing the UI

You can change UI elements displayed by the plugin. Here are the defaults:

```lua
-- In your setup() call:
require("sllm").setup({
  ui = {
    ask_llm_prompt = 'Prompt: ',
    add_url_prompt = 'URL: ',
    add_cmd_prompt = 'Command: ',
    markdown_prompt_header = '> 💬 Prompt:',
    markdown_response_header = '> 🤖 Response',
    set_system_prompt = 'System Prompt: ',

    -- You can omit a key to use the default
  },
})
```

---

## Pre-Hooks and Post-Hooks

Pre-hooks and post-hooks allow you to run shell commands automatically before
and after each LLM execution, enabling dynamic context generation and custom
workflows.

### Pre-Hooks

Pre-hooks run **before** the LLM is invoked. Each pre-hook can optionally
capture its output and add it to the context.

**Configuration:**

```lua
require("sllm").setup({
  pre_hooks = {
    {
      command = "git diff --cached",
      add_to_context = true,  -- Capture stdout/stderr and add to context
    },
    {
      command = "echo 'Starting LLM request...'",
      add_to_context = false,  -- Just run the command, don't capture
    },
  },
})
```

**Pre-Hook Fields:**

- `command` (string, required): Shell command to execute. Supports vim command
  expansion (e.g., `%` expands to current filename).
- `add_to_context` (boolean, optional): If `true`, captures the command's stdout
  and stderr, adding them to the context as a snippet. Defaults to `false`.

**Notes:**

- Output is added as a snippet labeled `Pre-hook-> <command>` with both stdout
  and stderr sections when present
- Pre-hook snippets follow the same lifecycle as other context items—they are
  cleared after each prompt if `reset_ctx_each_prompt` is `true` (the default)
- Pre-hooks execute synchronously in the order they are defined

### Post-Hooks

Post-hooks run **after** the LLM execution completes (both on success and
failure). They are useful for logging, cleanup, or triggering follow-up actions.

**Configuration:**

```lua
require("sllm").setup({
  post_hooks = {
    {
      command = "echo 'LLM request completed' >> /tmp/llm_log.txt",
    },
    {
      command = "notify-send 'SLLM' 'Request completed'",
    },
  },
})
```

**Post-Hook Fields:**

- `command` (string, required): Shell command to execute. Supports vim command
  expansion.

**Notes:**

- Post-hooks execute after the response is fully received and displayed
- Post-hooks run regardless of whether the LLM request succeeded or failed
- Output from post-hooks is not captured or displayed

### Example Use Cases

**1. Automatically include git diff in context:**

```lua
pre_hooks = {
  {
    command = "git diff HEAD",
    add_to_context = true,
  },
}
```

**2. Include current file content:**

```lua
pre_hooks = {
  {
    command = "cat %",  -- % expands to current filename
    add_to_context = true,
  },
}
```

**3. Log all LLM interactions:**

```lua
post_hooks = {
  {
    command = "date >> ~/.sllm_history.log",
  },
}
```

**4. Notify when long-running requests complete:**

```lua
post_hooks = {
  {
    command = "osascript -e 'display notification \"LLM request completed\" with title \"SLLM\"'",  -- macOS
  },
}
```

---

## Online/Web Mode Toggle

Some models may support an `online` option for web search capabilities. You can
easily toggle this feature:

**Quick Toggle**: Press `<leader>sW` to toggle online mode on/off

When enabled, you'll see a 🌐 icon in the status bar next to the model name.

**Example:**

```
Status bar shows: sllm.nvim | Model: gpt-4o 🌐    (online mode enabled)
Status bar shows: sllm.nvim | Model: gpt-4o       (online mode disabled)
```

**Enable by Default in Config:**

```lua
require("sllm").setup({
  online_enabled = true,  -- Start with online mode enabled
})
```

**Note**: The `online` option may not be available for all models. If you get
errors when using this feature, the model you're using likely doesn't support
web search. Check your model provider's documentation.

---

## Workflow Example

1. Open any file and press `<leader>ss` (ask); type your prompt and hit Enter.
2. **Complete code at cursor:** Press `<leader><Tab>` to auto-complete code
   (shows loading indicator while processing).
3. **Add context quickly:** `<leader>sa` adds file (normal mode) or selection
   (visual mode).
4. **Add extra context types:** `<leader>sA` opens a picker for URLs,
   diagnostics, shell commands, tools, or Python functions.
5. **Switch modes:** `<leader>sM` to change between `sllm_chat`, `sllm_read`,
   `sllm_agent`, etc.
6. **Switch models:** `<leader>sm` to pick a different LLM model.
7. Start a new chat: `<leader>sn`.
8. Cancel a running request: `<leader>sc`.
9. Toggle LLM buffer: `<leader>st`.
10. **Toggle online/web mode:** `<leader>sW` (check status bar for 🌐
    indicator).
11. **Browse and continue conversations:** `<leader>sh` to select from up to
    1000 recent conversations and continue chatting from any point.
12. **Copy code blocks from response:** `<leader>sy` copies the last code block.

### Visual Workflow

![sllm.nvim Workflow](./assets/workflow.png)

---

## History Navigation

sllm.nvim integrates with the `llm` CLI's logging feature to provide
conversation history browsing and continuation. The `llm` CLI automatically logs
all prompts and responses.

### Browse and Continue Conversations

Press `<leader>sh` to browse and continue previous conversations:

- View up to 1000 recent conversations (configurable via `history_max_entries`)
- See timestamps, models, message counts, and conversation previews
- Select a conversation to load all messages into the LLM buffer
- Continue chatting from where you left off - new prompts extend the selected
  conversation

**Example:**

1. Press `<leader>sh`
2. Select a conversation from the picker
3. Review the full conversation history in the LLM buffer
4. Press `<leader>ss` to add a new message and continue the conversation

### Configuring History Limit

By default, `browse_history` fetches the most recent 1000 log entries. You can
adjust this in your setup:

```lua
require("sllm").setup({
  history_max_entries = 2000,  -- Fetch more history (slower)
  -- or
  history_max_entries = 500,   # Fetch less history (faster)
})
```

**Performance Note:** Higher values provide access to more conversations but may
take longer to load. The default of 1000 provides a good balance between
performance and coverage.

### History Management

History is managed by the `llm` CLI. Common commands:

```sh
llm logs list              # View all logs
llm logs list -n 10        # View last 10 entries
llm logs list -q "search"  # Search logs
llm logs list -m "gpt-4o"  # Filter by model
llm logs status            # Check logging status
llm logs off               # Disable logging
llm logs on                # Enable logging
```

For more information: https://llm.datasette.io/en/stable/logging.html

---

## Internals

- **Context Manager** (`sllm.context_manager`) Tracks a list of file paths, text
  snippets, tool names, **and function definitions** to include in subsequent
  prompts.
- **Backend** (`sllm.backend.llm`) Builds and executes the `llm` CLI command,
  optionally adding `-T <tool>` for each active tool or
  `--functions <py_function>` for ad-hoc functions.
- **Job Manager** (`sllm.job_manager`) Spawns a Neovim job for the CLI, streams
  stdout line-by-line.
- **UI** (`sllm.ui`) Creates and manages a scratch markdown buffer to display
  streaming output.
- **History Manager** (`sllm.history_manager`) Fetches and formats chat history
  from `llm logs`.
- **Utils** (`sllm.utils`) Helper functions for buffer/window checks, path
  utilities, and more.

---

## Contributions & Credits

- The core LLM interaction is powered by Simon Willison’s excellent
  [`llm`](https://github.com/simonw/llm) CLI.
- The user interface components (notifications, pickers) are provided by the
  versatile [echasnovski/mini.nvim](https://github.com/echasnovski/mini.nvim)
  library.
- `sllm.nvim` itself is created and maintained by **mozanunal**, focusing on
  integrating these tools smoothly into Neovim.

---

## License

Apache 2.0 — see [LICENSE](./LICENSE). `llm` and its extensions are copyright
Simon Willison.
