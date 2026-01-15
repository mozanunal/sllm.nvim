# Configure sllm.nvim {#sllm-configure}

This guide shows the default configuration and how to change keymaps or add
slash commands.

## Default configuration

Call `setup()` with no arguments to use the defaults:

```lua
require('sllm').setup({
  backend_config = { cmd = 'llm' },
  default_model = 'default',
  default_mode = 'sllm_chat',
  on_start_new_chat = true,
  reset_ctx_each_prompt = true,
  window_type = 'vertical',
  scroll_to_bottom = true,
  pick_func = (pcall(require, 'mini.pick') and require('mini.pick').ui_select) or vim.ui.select,
  notify_func = (pcall(require, 'mini.notify') and require('mini.notify').make_notify()) or vim.notify,
  input_func = vim.ui.input,
  pre_hooks = nil,
  post_hooks = nil,
  history_max_entries = 1000,
  chain_limit = 100,
  keymaps = {
    ask = '<leader>ss',
    select_model = '<leader>sm',
    select_mode = '<leader>sM',
    add_context = '<leader>sa',
    commands = '<leader>sx',
    new_chat = '<leader>sn',
    cancel = '<leader>sc',
    toggle_buffer = '<leader>st',
    history = '<leader>sh',
    copy_code = '<leader>sy',
    complete = '<leader><Tab>',
  },
  ui = {
    show_usage = true,
    ask_llm_prompt = 'Prompt: ',
    add_url_prompt = 'URL: ',
    add_cmd_prompt = 'Command: ',
    markdown_prompt_header = '> 💬 Prompt:',
    markdown_response_header = '> 🤖 Response',
    set_system_prompt = 'System Prompt: ',
  },
})
```

## Customizing keymaps

- Omit `keymaps` to keep the defaults.
- Set a specific key to a new mapping: `ask = '<leader>a'`.
- Disable one by setting it to `false` or `nil`.
- Disable all defaults by setting `keymaps = false`, then define your own
  mappings that call functions like `require('sllm').ask_llm()` or
  `require('sllm').commands`.

## Adjusting UI and behavior

- Switch window type with `window_type = 'horizontal'` or `'float'`.
- Keep context across prompts by setting `reset_ctx_each_prompt = false`.
- Start with online mode enabled via `online_enabled = true`.
- Change prompts and headers in the `ui` table (see defaults above).

## Adding slash commands to your config

Slash commands are handled by `Sllm.run_command` and map to the internal command
registry. Today the registry is fixed inside the plugin. If you need custom
slash commands, the supported approach is to add your own keymaps that call your
functions directly (for example,
`vim.keymap.set({ 'n', 'v' }, '<leader>sx', my_fn)`) or open a PR to expose a
public extension point.

## Key hints

- `default_model = 'default'` respects the model configured in the `llm` CLI.
- `history_max_entries` controls how many conversations are fetched in the
  history picker.
- `chain_limit` caps how many tool calls the agent can make in a single
  interaction.
