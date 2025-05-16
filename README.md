# sllm.nvim

**sllm.nvim** is a Neovim plugin that brings [Simon Willison's `llm`](https://github.com/simonw/llm) command-line interface for large language models directly to your editor, making it easy to chat with LLMs, insert code from context, manage models, and more. Manage the context of your prompts very easily using the keybindings, also the output of the llm chat is just another neovim buffer you can navigate and use *speed of thoughts* with vim navigation keybindings ⚡.

---

## Quick Start

### 1. Install [`llm`](https://github.com/simonw/llm) (by [simonw](https://github.com/simonw))

- Install via pip or brew or any other method given in the link above:

```sh
brew install llm
```

- For more details and latest releases, see the [llm repository](https://github.com/simonw/llm).

### 2. Install llm Extensions

- For OpenAI (GPT-4.1/4o, etc):

```sh
llm install llm-openai
# or openrouter ext. offers 300+ different models
llm install llm-openrouter
# or gpt4all to use local models
llm install llm-gpt4all
```
- Find more plugins at [llm-extensions](https://llm.datasette.io/en/stable/plugins/installing-plugins.html).

### 3. Set your OpenAI API Key

```sh
llm keys set openai
```
_Follow prompts, or set the `OPENAI_API_KEY` environment variable._

### 4. Set a Default Model (recommended)

List models:

```sh
llm models
```

Set default (replace `MODEL_NAME` with your preferred model, e.g., `gpt-4.1`):

```sh
llm models default gpt-4.1
```

---

## 5. Install sllm.nvim

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mozanunal/sllm.nvim",
  config = function()
    require('sllm').setup()
  end,
  dependencies = {
    "echasnovski/mini.notify",
    "echasnovski/mini.pick"
  }
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "mozanunal/sllm.nvim",
  config = function() require("sllm").setup() end,
  requires = { "echasnovski/mini.notify", "echasnovski/mini.pick" }
})
```

---

## Usage

**Key mappings:**

| Mapping         | Mode | Description                     |
|-----------------|------|---------------------------------|
| `<leader>ss`    | n/v  | Ask LLM (prompt, optionally with visual selection)  |
| `<leader>sn`    | n    | Start a new chat session        |
| `<leader>sc`    | n    | Cancel ongoing LLM request      |
| `<leader>sa`    | n    | Add current file to LLM context |
| `<leader>sr`    | n    | Reset (clear) LLM context       |
| `<leader>sf`    | n    | Focus LLM output window         |
| `<leader>st`    | n    | Toggle LLM buffer visibility    |
| `<leader>sm`    | n    | Select LLM model interactively  |

**Sample workflow:**

1. Press `<leader>ss` and enter your prompt.
2. Visual select code and press `<leader>ss` to send the selection as context.
3. Use `<leader>sa` to add files as reference for better responses.
4. Switch models anytime with `<leader>sm`.

---

## Commands & Features

- **Context Management:** Reference multiple files in your query for more relevant answers.
- **Streaming Output:** Responses appear streamed in a split buffer.
- **Model Selection:** Easily switch between multiple LLM backends.
- **Asynchronous Jobs:** Requests won't block your editor.
- **Notifications**: All actions report helpful status and errors in the status area.

---

## Code Documentation

**Plugin Structure:**

- All functions are provided under the `require('sllm')` Lua module.
- Uses [`mini.notify`](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-notify.md) and [`mini.pick`](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-pick.md) for notifications and model selection respectively.
- Chats and LLM responses are displayed in a scratch buffer with markdown highlighting and convenient window management.
- Context management lets you add/reset file context per session.
- LLM requests use the same command line flags as `llm`.

See [`sllm.lua`](./sllm.lua) for further inline documentation and implementation details.

---

## Credits & Inspiration

- Inspired by [Simon Willison's `llm` CLI tool](https://github.com/simonw/llm), which powers model interaction.
- Thanks to [`echasnovski/mini.nvim`](https://github.com/echasnovski/mini.nvim) for mini.* plugins used here.
- Created by mozanunal.

---

## License

MIT (see `LICENSE`).
`llm` is copyright [Simon Willison](https://github.com/simonw).


