--- *sllm.nvim* Integrate Simon Willison's llm CLI into Neovim
---
--- MIT License Copyright (c) 2025 mozanunal
---
---                                                                         *Sllm*
---
---@toc_entry Introduction
---@text
--- # Introduction
---
--- sllm.nvim is a Neovim plugin that integrates Simon Willison's `llm` CLI
--- directly into your editor. Chat with large language models, stream responses
--- in a scratch buffer, manage context files, switch models or tool integrations
--- on the fly, and control everything asynchronously without leaving Neovim.
---
--- Features:
---   • Interactive chat with streaming responses
---   • Code completion at cursor position
---   • History navigation (browse and continue conversations)
---   • Context management (files, URLs, selections, diagnostics, etc.)
---   • Model and tool selection
---   • On-the-fly Python function tools
---   • Asynchronous, non-blocking requests
---   • Split buffer UI with markdown rendering
---   • Token usage feedback
---   • Code block extraction
---
---@toc_entry Requirements
---@text
--- # Requirements
---
--- 1. The `llm` CLI must be installed:
---    https://github.com/simonw/llm
---
--- 2. At least one `llm` extension (e.g., `llm install llm-openai`)
---
--- 3. Configure API keys (e.g., `llm keys set openai`)
---
---@toc_entry Installation
---@text
--- # Installation
---
--- Using lazy.nvim: >lua
---   {
---     "mozanunal/sllm.nvim",
---     dependencies = {
---       "echasnovski/mini.notify",  -- optional
---       "echasnovski/mini.pick",    -- optional
---     },
---     config = function()
---       require("sllm").setup({
---         -- your custom options here
---       })
---     end,
---   }
--- <
---
---@toc_entry Configuration
---@text
--- # Configuration ~
---
--- All configuration options with their defaults: >lua
---   require("sllm").setup({
---     llm_cmd = "llm",            -- Command or path for the llm CLI
---     default_model = "default",  -- Model to use (or "default" for llm's default)
---     show_usage = true,          -- Show token usage stats after responses
---     on_start_new_chat = true,   -- Start with fresh chat on setup
---     reset_ctx_each_prompt = true, -- Clear context after each prompt
---     window_type = "vertical",   -- "vertical", "horizontal", or "float"
---     scroll_to_bottom = true,    -- Auto-scroll to bottom of LLM window
---     pick_func = vim.ui.select,  -- Function for item selection
---     notify_func = vim.notify,   -- Function for notifications
---     input_func = vim.ui.input,  -- Function for input prompts
---     keymaps = { ... },          -- See |Sllm-keymaps|
---     pre_hooks = nil,            -- Commands before LLM execution
---     post_hooks = nil,           -- Commands after LLM execution
---     system_prompt = "...",      -- System prompt for all queries
---     model_options = {},         -- Model-specific options (-o flags)
---     online_enabled = false,     -- Enable web search by default
---     history_max_entries = 1000, -- Max history entries to fetch
---   })
--- <
--- ## Configuration Options ~
---
--- `llm_cmd` - Command or full path to the `llm` CLI executable.
---
--- `default_model` - Model to use on startup. Set to "default" to use the
--- default model configured in `llm`.
---
--- `show_usage` - When `true`, displays token usage and estimated cost after
--- each response.
---
--- `on_start_new_chat` - When `true`, starts with a fresh chat buffer on setup.
---
--- `reset_ctx_each_prompt` - When `true`, automatically clears file context
--- after each prompt. Set to `false` to persist context across prompts.
---
--- `window_type` - Controls how the LLM buffer opens:
---   • "vertical" - Split vertically
---   • "horizontal" - Split horizontally
---   • "float" - Floating window
---
--- `scroll_to_bottom` - When `true`, keeps cursor at bottom of LLM window as
--- responses stream in.
---
--- `pick_func`, `notify_func`, `input_func` - UI functions for selections,
--- notifications, and input prompts. Defaults to vim.ui.* functions but can
--- use mini.pick and mini.notify for enhanced UI.
---
--- `keymaps` - Table of keybindings. See |Sllm-keymaps|. Set to `false` to
--- disable all default keymaps.
---
--- `system_prompt` - Text prepended to all queries via `-s` flag. Useful for
--- ensuring consistent output formatting. See |Sllm-system-prompt|.
---
--- `model_options` - Table of model-specific options passed via `-o` flags.
--- Example: `{ temperature = 0.7, max_tokens = 1000 }`. See |Sllm-model-options|.
---
--- `online_enabled` - When `true`, enables web search capabilities (shows 🌐
--- in status bar). Not all models support this.
---
--- `history_max_entries` - Maximum number of conversation history entries to
--- fetch. Higher values show more history but may be slower.
---
---@toc_entry Keymaps
---@text
---                                                                 *Sllm-keymaps*
--- # Keymaps ~
---
--- Default keybindings (all can be customized or disabled):
---
--- Keymap                  | Default Key   | Modes | Description
--- ----------------------- | ------------- | ----- | ---------------------------
--- `ask_llm`               | `<leader>ss`  | n,v   | Prompt the LLM
--- `new_chat`              | `<leader>sn`  | n,v   | Start new chat
--- `cancel`                | `<leader>sc`  | n,v   | Cancel current request
--- `focus_llm_buffer`      | `<leader>sf`  | n,v   | Focus LLM buffer
--- `toggle_llm_buffer`     | `<leader>st`  | n,v   | Toggle LLM buffer
--- `select_model`          | `<leader>sm`  | n,v   | Select model
--- `toggle_online`         | `<leader>sW`  | n,v   | Toggle online/web mode
--- `set_model_option`      | `<leader>so`  | n,v   | Set model option
--- `show_model_options`    | `<leader>sO`  | n,v   | Show model options
--- `add_file_to_ctx`       | `<leader>sa`  | n,v   | Add current file
--- `add_url_to_ctx`        | `<leader>su`  | n,v   | Add URL content
--- `add_sel_to_ctx`        | `<leader>sv`  | v     | Add visual selection
--- `add_diag_to_ctx`       | `<leader>sd`  | n,v   | Add diagnostics
--- `add_cmd_out_to_ctx`    | `<leader>sx`  | n,v   | Add command output
--- `add_tool_to_ctx`       | `<leader>sT`  | n,v   | Add tool
--- `add_func_to_ctx`       | `<leader>sF`  | n,v   | Add Python function
--- `reset_context`         | `<leader>sr`  | n,v   | Reset context
--- `set_system_prompt`     | `<leader>sS`  | n,v   | Set system prompt
--- `browse_history`        | `<leader>sh`  | n,v   | Browse history
--- `copy_last_code_block`  | `<leader>sy`  | n,v   | Copy last code block
--- `copy_first_code_block` | `<leader>sY`  | n,v   | Copy first code block
--- `copy_last_response`    | `<leader>sE`  | n,v   | Copy last response
--- `complete_code`         | `<leader><Tab>` | n,v | Complete code at cursor
---
--- ## Customizing Keymaps ~
---
--- Change specific keymaps: >lua
---   require("sllm").setup({
---     keymaps = {
---       ask_llm = "<leader>a",    -- Change to <leader>a
---       add_url_to_ctx = false,   -- Disable this keymap
---     },
---   })
--- <
--- Disable all default keymaps: >lua
---   require("sllm").setup({
---     keymaps = false,
---   })
---
---   -- Then define your own
---   vim.keymap.set("n", "<leader>a", require("sllm").ask_llm)
--- <
---
---@toc_entry Usage
---@text
--- # Usage ~
---
--- ## Basic Workflow ~
---
--- 1. Press `<leader>ss` - Ask the LLM a question
--- 2. Press `<leader>sa` - Add current file to context
--- 3. Press `<leader>sv` (visual mode) - Add selection to context
--- 4. Press `<leader>sm` - Switch models
--- 5. Press `<leader>sh` - Browse and continue previous conversations
--- 6. Press `<leader><Tab>` - Complete code at cursor position
---
--- ## Code Completion ~
---
--- The code completion feature (`<leader><Tab>`) sends code before and after
--- your cursor to the LLM for intelligent completion:
---
--- 1. Position cursor where you want completion
--- 2. Press `<leader><Tab>`
--- 3. LLM analyzes context and inserts completion
---
--- ## Context Management ~
---
--- Build context for better LLM responses:
--- - `<leader>sa` - Add entire current file
--- - `<leader>sv` - Add visual selection (in visual mode)
--- - `<leader>sd` - Add diagnostics (errors/warnings)
--- - `<leader>su` - Add content from a URL
--- - `<leader>sx` - Add output from shell command
--- - `<leader>sT` - Add an installed llm tool
--- - `<leader>sF` - Add Python function as a tool
--- - `<leader>sr` - Clear all context
---
--- Context is automatically cleared after each prompt by default
--- (configurable with `reset_ctx_each_prompt`).
---
--- ## History Navigation ~
---
--- Press `<leader>sh` to browse previous conversations:
--- - View up to 1000 recent conversations (configurable)
--- - See timestamps, models, and message counts
--- - Select a conversation to load and continue chatting
---
--- The `llm` CLI logs all interactions automatically. You can manage logs
--- with: `llm logs list`, `llm logs off`, etc.
---
---@toc_entry System Prompt
---@text
---                                                          *Sllm-system-prompt*
--- # System Prompt ~
---
--- The system prompt is prepended to all queries using the `-s` flag. This
--- ensures consistent behavior and output formatting.
---
--- ## Default System Prompt ~
--- >
---   You are a sllm plugin living within neovim.
---   Always answer with markdown.
---   If the offered change is small, return only the changed part or
---   function, not the entire file.
--- <
--- ## Configure in setup() ~
--- >lua
---   require("sllm").setup({
---     system_prompt = [[You are an expert code reviewer.
---   Always provide constructive feedback.
---   Format code suggestions using markdown code blocks.]],
---   })
--- <
--- ## Update on-the-fly ~
---
--- Press `<leader>sS` to interactively update the system prompt during a
--- session. This allows you to adapt the LLM's behavior without restarting
--- Neovim. Submit an empty string to clear the system prompt.
---
---@toc_entry Model Options
---@text
---                                                          *Sllm-model-options*
--- # Model Options ~
---
--- Models support specific options passed via `-o` flags. Common options
--- include temperature, max_tokens, and more.
---
--- ## Discover Options ~
---
--- Press `<leader>sO` (capital O) to see available options for your current
--- model, or run: `llm models --options -m <model-name>`
---
--- ## Set Options in Config ~
--- >lua
---   require("sllm").setup({
---     model_options = {
---       temperature = 0.7,     -- Control randomness (0-2)
---       max_tokens = 1000,     -- Limit response length
---       top_p = 0.9,          -- Nucleus sampling
---       seed = 42,            -- Deterministic sampling
---     },
---   })
--- <
--- ## Set Options at Runtime ~
---
--- Press `<leader>so` to set an option on-the-fly:
--- 1. Enter option key (e.g., `temperature`)
--- 2. Enter option value (e.g., `0.7`)
---
--- Or use Lua: >lua
---   require("sllm").set_model_option()
---   require("sllm").reset_model_options()  -- Clear all options
--- <
--- ## Common Options ~
---
--- - `temperature` (0-2) - Randomness: higher = creative, lower = focused
--- - `max_tokens` - Maximum tokens to generate
--- - `top_p` (0-1) - Nucleus sampling (alternative to temperature)
--- - `frequency_penalty` (-2 to 2) - Penalize repeated tokens
--- - `presence_penalty` (-2 to 2) - Encourage new topics
--- - `seed` - Integer for deterministic outputs
--- - `json_object` (boolean) - Force JSON output
--- - `reasoning_effort` (low/medium/high) - For reasoning models
--- - `image_detail` (low/high/auto) - For vision models
---
--- Not all options are available for all models.
---
---@toc_entry Pre/Post Hooks
---@text
---                                                               *Sllm-hooks*
--- # Pre-Hooks and Post-Hooks ~
---
--- Hooks allow running shell commands before and after LLM execution.
---
--- ## Pre-Hooks ~
---
--- Run before LLM invocation. Can capture output and add to context: >lua
---   require("sllm").setup({
---     pre_hooks = {
---       {
---         command = "git diff --cached",
---         add_to_context = true,  -- Capture and add to context
---       },
---       {
---         command = "echo 'Starting LLM...'",
---         add_to_context = false,  -- Just run, don't capture
---       },
---     },
---   })
--- <
--- Pre-hook output is added as a snippet labeled `Pre-hook-> <command>`.
---
--- ## Post-Hooks ~
---
--- Run after LLM completes (both on success and failure): >lua
---   require("sllm").setup({
---     post_hooks = {
---       {
---         command = "date >> ~/.sllm_history.log",
---       },
---       {
---         command = "notify-send 'SLLM' 'Request completed'",
---       },
---     },
---   })
--- <
--- Post-hook output is not captured or displayed.
---
--- ## Use Cases ~
---
--- - Automatically include git diff: `git diff HEAD`
--- - Include current file: `cat %` (% expands to filename)
--- - Log interactions: `date >> log.txt`
--- - Desktop notifications: `notify-send ...`
---
---@toc_entry Online Mode
---@text
---                                                            *Sllm-online-mode*
--- # Online/Web Mode ~
---
--- Some models support an `online` option for web search capabilities.
---
--- ## Toggle Online Mode ~
---
--- Press `<leader>sW` to toggle online mode. When enabled, you'll see a 🌐
--- icon in the status bar.
---
--- Status bar examples:
---   `sllm.nvim | Model: gpt-4o 🌐`    (online mode enabled)
---   `sllm.nvim | Model: gpt-4o`       (online mode disabled)
---
--- ## Enable by Default ~
--- >lua
---   require("sllm").setup({
---     online_enabled = true,
---   })
--- <
--- Note: Not all models support online mode. Check your model provider's
--- documentation.
---
---@tag sllm.nvim
---@tag sllm

---@class SllmKeymaps
---@field ask_llm string|false|nil             Keymap for asking the LLM.
---@field new_chat string|false|nil            Keymap for starting a new chat.
---@field cancel string|false|nil              Keymap for canceling a request.
---@field focus_llm_buffer string|false|nil    Keymap for focusing the LLM window.
---@field toggle_llm_buffer string|false|nil   Keymap for toggling the LLM window.
---@field select_model string|false|nil        Keymap for selecting an LLM model.
---@field add_file_to_ctx string|false|nil     Keymap for adding current file to context.
---@field add_url_to_ctx string|false|nil      Keymap for adding a URL to context.
---@field add_sel_to_ctx string|false|nil      Keymap for adding visual selection.
---@field add_diag_to_ctx string|false|nil     Keymap for adding diagnostics.
---@field add_cmd_out_to_ctx string|false|nil  Keymap for adding command output.
---@field add_tool_to_ctx string|false|nil     Keymap for adding a tool.
---@field add_func_to_ctx string|false|nil     Keymap for adding a function.
---@field reset_context string|false|nil       Keymap for resetting the context.
---@field set_system_prompt string|false|nil   Keymap for setting the system prompt.
---@field set_model_option string|false|nil    Keymap for setting model options.
---@field show_model_options string|false|nil  Keymap for showing available model options.
---@field toggle_online string|false|nil       Keymap for toggling online mode.
---@field copy_first_code_block string|false|nil  Keymap for copying the first code block.
---@field copy_last_code_block string|false|nil   Keymap for copying the last code block.
---@field copy_last_response string|false|nil     Keymap for copying the last response.
---@field complete_code string|false|nil          Keymap for triggering code completion at cursor.
---@field browse_history string|false|nil         Keymap for browsing chat history.

---@class PreHook
---@field command string                     Shell command to execute.
---@field add_to_context boolean?            Whether to capture stdout and add to context (default: false).

---@class PostHook
---@field command string                     Shell command to execute.

---@class SllmConfig
---@field llm_cmd string                     Command to run the LLM CLI.
---@field default_model string               Default model name or `"default"`.
---@field show_usage boolean                 Show usage examples flag.
---@field on_start_new_chat boolean          Whether to reset conversation on start.
---@field reset_ctx_each_prompt boolean      Whether to clear context after each prompt.
---@field window_type "'vertical'"|"'horizontal'"|"'float'"  How to open the chat window.
---@field scroll_to_bottom boolean           Whether to keep the cursor at the bottom of the LLM window.
---@field pick_func fun(items: any[], opts: table?, on_choice: fun(item: any, idx?: integer))  Selector UI.
---@field notify_func fun(msg: string, level?: number)      Notification function.
---@field input_func fun(opts: table, on_confirm: fun(input: string?))  Input prompt function.
---@field keymaps SllmKeymaps|false|nil      Collection of keybindings.
---@field pre_hooks PreHook[]?               Commands to run before llm execution.
---@field post_hooks PostHook[]?             Commands to run after llm execution.
---@field system_prompt string?              System prompt to prepend to all queries.
---@field model_options table<string,any>?   Model-specific options to pass with -o flag.
---@field online_enabled boolean?            Enable online/web mode by default.
---@field history_max_entries integer?       Maximum number of history entries to fetch (default: 1000).
-- Module definition ==========================================================
local Sllm = {}
local H = {}

-- Helper data ================================================================
-- Module default config
H.default_config = vim.deepcopy({
  llm_cmd = 'llm',
  default_model = 'default',
  show_usage = true,
  on_start_new_chat = true,
  reset_ctx_each_prompt = true,
  window_type = 'vertical',
  scroll_to_bottom = true,
  pick_func = (pcall(require, 'mini.pick') and require('mini.pick').ui_select) or vim.ui.select,
  notify_func = (pcall(require, 'mini.notify') and require('mini.notify').make_notify()) or vim.notify,
  input_func = vim.ui.input,
  pre_hooks = nil,
  post_hooks = nil,
  system_prompt = [[You are a sllm plugin living within neovim.
Always answer with markdown.
If the offered change is small, return only the changed part or function, not the entire file.]],
  history_max_entries = 1000,
  keymaps = {
    ask_llm = '<leader>ss',
    new_chat = '<leader>sn',
    cancel = '<leader>sc',
    focus_llm_buffer = '<leader>sf',
    toggle_llm_buffer = '<leader>st',
    select_model = '<leader>sm',
    add_file_to_ctx = '<leader>sa',
    add_url_to_ctx = '<leader>su',
    add_sel_to_ctx = '<leader>sv',
    add_diag_to_ctx = '<leader>sd',
    add_cmd_out_to_ctx = '<leader>sx',
    add_tool_to_ctx = '<leader>sT',
    add_func_to_ctx = '<leader>sF',
    reset_context = '<leader>sr',
    set_system_prompt = '<leader>sS',
    set_model_option = '<leader>so',
    show_model_options = '<leader>sO',
    toggle_online = '<leader>sW',
    copy_first_code_block = '<leader>sY',
    copy_last_code_block = '<leader>sy',
    copy_last_response = '<leader>sE',
    complete_code = '<leader><Tab>',
    browse_history = '<leader>sh',
  },
})

-- Internal modules
H.utils = require('sllm.utils')
H.backend = require('sllm.backend.llm')
H.context_manager = require('sllm.context_manager')
H.job_manager = require('sllm.job_manager')
H.ui = require('sllm.ui')
H.history_manager = require('sllm.history_manager')

-- Internal state
H.state = {
  continue = nil, -- Can be boolean or conversation_id string
  selected_model = nil,
  system_prompt = nil,
  model_options = {},
  online_enabled = false,
}

-- Internal functions for UI
H.notify = vim.notify
H.pick = vim.ui.select
H.input = vim.ui.input

-- Module setup ===============================================================
--- Module setup
---
---@param config table|nil Module config table. See |Sllm.config|.
---
---@usage >lua
---   require('sllm').setup() -- use default config
---   -- OR
---   require('sllm').setup({}) -- replace {} with your config table
--- <
Sllm.setup = function(config)
  -- Export module
  _G.Sllm = Sllm

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)
end

--- Defaults ~
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
Sllm.config = vim.deepcopy(H.default_config)
--minidoc_afterlines_end

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})
  return config
end

H.apply_config = function(config)
  Sllm.config = config

  local km = Sllm.config.keymaps
  if km then
    local keymap_defs = {
      ask_llm = { modes = { 'n', 'v' }, func = Sllm.ask_llm, desc = 'Ask LLM' },
      new_chat = { modes = { 'n', 'v' }, func = Sllm.new_chat, desc = 'New LLM chat' },
      cancel = { modes = { 'n', 'v' }, func = Sllm.cancel, desc = 'Cancel LLM request' },
      focus_llm_buffer = { modes = { 'n', 'v' }, func = Sllm.focus_llm_buffer, desc = 'Focus LLM buffer' },
      toggle_llm_buffer = { modes = { 'n', 'v' }, func = Sllm.toggle_llm_buffer, desc = 'Toggle LLM buffer' },
      select_model = { modes = { 'n', 'v' }, func = Sllm.select_model, desc = 'Select LLM model' },
      add_tool_to_ctx = { modes = { 'n', 'v' }, func = Sllm.add_tool_to_ctx, desc = 'Add tool to context' },
      add_file_to_ctx = { modes = { 'n', 'v' }, func = Sllm.add_file_to_ctx, desc = 'Add file to context' },
      add_url_to_ctx = { modes = { 'n', 'v' }, func = Sllm.add_url_to_ctx, desc = 'Add URL to context' },
      add_diag_to_ctx = { modes = { 'n', 'v' }, func = Sllm.add_diag_to_ctx, desc = 'Add diagnostics to context' },
      add_cmd_out_to_ctx = {
        modes = { 'n', 'v' },
        func = Sllm.add_cmd_out_to_ctx,
        desc = 'Add command output to context',
      },
      reset_context = { modes = { 'n', 'v' }, func = Sllm.reset_context, desc = 'Reset LLM context' },
      add_sel_to_ctx = { modes = 'v', func = Sllm.add_sel_to_ctx, desc = 'Add visual selection to context' },
      add_func_to_ctx = { modes = 'n', func = Sllm.add_func_to_ctx, desc = 'Add selected function to context' },
      set_system_prompt = { modes = { 'n', 'v' }, func = Sllm.set_system_prompt, desc = 'Set system prompt' },
      set_model_option = { modes = { 'n', 'v' }, func = Sllm.set_model_option, desc = 'Set model option' },
      show_model_options = {
        modes = { 'n', 'v' },
        func = Sllm.show_model_options,
        desc = 'Show available model options',
      },
      toggle_online = { modes = { 'n', 'v' }, func = Sllm.toggle_online, desc = 'Toggle online mode' },
      copy_first_code_block = {
        modes = { 'n', 'v' },
        func = Sllm.copy_first_code_block,
        desc = 'Copy first code block',
      },
      copy_last_code_block = { modes = { 'n', 'v' }, func = Sllm.copy_last_code_block, desc = 'Copy last code block' },
      copy_last_response = { modes = { 'n', 'v' }, func = Sllm.copy_last_response, desc = 'Copy last response' },
      complete_code = { modes = { 'n', 'v' }, func = Sllm.complete_code, desc = 'Complete code at cursor' },
      browse_history = { modes = { 'n', 'v' }, func = Sllm.browse_history, desc = 'Browse chat history' },
    }

    for name, def in pairs(keymap_defs) do
      local key = km[name]
      if type(key) == 'string' and key ~= '' then vim.keymap.set(def.modes, key, def.func, { desc = def.desc }) end
    end
  end

  H.state.continue = not Sllm.config.on_start_new_chat
  H.state.selected_model = Sllm.config.default_model ~= 'default' and Sllm.config.default_model
    or H.backend.get_default_model(Sllm.config.llm_cmd)
  H.state.system_prompt = Sllm.config.system_prompt
  H.state.model_options = Sllm.config.model_options or {}
  H.state.online_enabled = Sllm.config.online_enabled or false

  -- Set online option if enabled by default
  if H.state.online_enabled then H.state.model_options.online = 1 end

  H.notify = Sllm.config.notify_func
  H.pick = Sllm.config.pick_func
  H.input = Sllm.config.input_func
end

-- Public API =================================================================

---@tag sllm.ask_llm()
--- Ask the LLM with a prompt from the user.
---
--- Prompt the LLM with user input. If in visual mode, automatically adds
--- the selection to context before prompting.
---
---@return nil
function Sllm.ask_llm()
  if H.utils.is_mode_visual() then Sllm.add_sel_to_ctx() end
  H.input({ prompt = 'Prompt: ' }, function(user_input)
    if user_input == '' then
      H.notify('[sllm] no prompt provided.', vim.log.levels.INFO)
      return
    end
    if user_input == nil then
      H.notify('[sllm] prompt canceled.', vim.log.levels.INFO)
      return
    end

    H.ui.show_llm_buffer(Sllm.config.window_type, H.state.selected_model, H.state.online_enabled)
    if H.job_manager.is_busy() then
      H.notify('[sllm] already running, please wait.', vim.log.levels.WARN)
      return
    end

    if Sllm.config.pre_hooks then
      for _, hook in ipairs(Sllm.config.pre_hooks) do
        local output = H.job_manager.exec_cmd_capture_output(hook.command)
        if hook.add_to_context then
          H.context_manager.add_snip(output, 'Pre-hook-> ' .. hook.command, 'text')
          H.notify('[sllm] pre-hook executed, added to context ' .. hook.command, vim.log.levels.INFO)
        end
      end
    end

    local ctx = H.context_manager.get()
    local prompt = H.context_manager.render_prompt_ui(user_input)
    H.ui.append_to_llm_buffer({ '', '> 💬 Prompt:', '' }, Sllm.config.scroll_to_bottom)
    H.ui.append_to_llm_buffer(vim.split(prompt, '\n', { plain = true }), Sllm.config.scroll_to_bottom)
    H.ui.start_loading_indicator()

    local cmd = H.backend.llm_cmd(
      Sllm.config.llm_cmd,
      prompt,
      H.state.continue,
      Sllm.config.show_usage,
      H.state.selected_model,
      ctx.fragments,
      ctx.tools,
      ctx.functions,
      H.state.system_prompt,
      H.state.model_options
    )
    H.state.continue = true

    local first_line = false
    H.job_manager.start(
      cmd,
      ---@param line string
      function(line)
        if not first_line then
          H.ui.stop_loading_indicator()
          H.ui.append_to_llm_buffer({ '', '> 🤖 Response', '' }, Sllm.config.scroll_to_bottom)
          first_line = true
        end
        H.ui.append_to_llm_buffer({ line }, Sllm.config.scroll_to_bottom)
      end,
      ---@param exit_code integer
      function(exit_code)
        H.ui.stop_loading_indicator()
        if not first_line then
          H.ui.append_to_llm_buffer({ '', '> 🤖 Response', '' }, Sllm.config.scroll_to_bottom)
          local msg = exit_code == 0 and '(empty response)' or string.format('(failed or canceled: exit %d)', exit_code)
          H.ui.append_to_llm_buffer({ msg }, Sllm.config.scroll_to_bottom)
        end
        H.notify('[sllm] done ✅ exit code: ' .. exit_code, vim.log.levels.INFO)
        H.ui.append_to_llm_buffer({ '' }, Sllm.config.scroll_to_bottom)
        if Sllm.config.reset_ctx_each_prompt then H.context_manager.reset() end
        if Sllm.config.post_hooks then
          for _, hook in ipairs(Sllm.config.post_hooks) do
            local _ = H.job_manager.exec_cmd_capture_output(hook.command)
          end
        end
      end
    )
  end)
end

--- Cancel the in-flight LLM request, if any.
---@return nil
function Sllm.cancel()
  if H.job_manager.is_busy() then
    H.job_manager.stop()
    H.notify('[sllm] canceling request...', vim.log.levels.WARN)
  else
    H.notify('[sllm] no active llm job', vim.log.levels.INFO)
  end
end

--- Start a new chat (clears buffer and state).
---@return nil
function Sllm.new_chat()
  if H.job_manager.is_busy() then
    H.job_manager.stop()
    H.notify('[sllm] previous request canceled for new chat.', vim.log.levels.INFO)
  end
  H.state.continue = false
  H.ui.show_llm_buffer(Sllm.config.window_type, H.state.selected_model, H.state.online_enabled)
  H.ui.clean_llm_buffer()
  H.notify('[sllm] new chat created', vim.log.levels.INFO)
end

--- Focus the existing LLM window or create it.
---@return nil
function Sllm.focus_llm_buffer()
  H.ui.focus_llm_buffer(Sllm.config.window_type, H.state.selected_model, H.state.online_enabled)
end

--- Toggle visibility of the LLM window.
---@return nil
function Sllm.toggle_llm_buffer()
  H.ui.toggle_llm_buffer(Sllm.config.window_type, H.state.selected_model, H.state.online_enabled)
end

--- Prompt user to select an LLM model.
---@return nil
function Sllm.select_model()
  local models = H.backend.extract_models(Sllm.config.llm_cmd)
  if not (models and #models > 0) then
    H.notify('[sllm] no models found.', vim.log.levels.ERROR)
    return
  end
  H.pick(models, {}, function(item)
    if item then
      H.state.selected_model = item
      H.notify('[sllm] selected model: ' .. item, vim.log.levels.INFO)
      H.ui.update_llm_win_title(H.state.selected_model, H.state.online_enabled)
    else
      H.notify('[sllm] llm model not changed', vim.log.levels.WARN)
    end
  end)
end

--- Add a tool to the current context.
---@return nil
function Sllm.add_tool_to_ctx()
  local tools = H.backend.extract_tools(Sllm.config.llm_cmd)
  if not (tools and #tools > 0) then
    H.notify('[sllm] no tools found.', vim.log.levels.ERROR)
    return
  end
  H.pick(tools, {}, function(item)
    if item then
      H.context_manager.add_tool(item)
      H.notify('[sllm] tool added: ' .. item, vim.log.levels.INFO)
    else
      H.notify('[sllm] no tools added.', vim.log.levels.WARN)
    end
  end)
end

--- Add the current file (or URL) path to the context.
---@return nil
function Sllm.add_file_to_ctx()
  local buf_path = H.utils.get_path_of_buffer(0)
  if buf_path then
    H.context_manager.add_fragment(buf_path)
    H.notify('[sllm] context +' .. H.utils.get_relpath(buf_path), vim.log.levels.INFO)
  else
    H.notify('[sllm] buffer does not have a path.', vim.log.levels.WARN)
  end
end

--- Prompt user for a URL and add it to context.
---@return nil
function Sllm.add_url_to_ctx()
  H.input({ prompt = 'URL: ' }, function(user_input)
    if user_input == '' then
      H.notify('[sllm] no URL provided.', vim.log.levels.INFO)
      return
    end
    H.context_manager.add_fragment(user_input)
    H.notify('[sllm] URL added to context: ' .. user_input, vim.log.levels.INFO)
  end)
end

--- Add the current function or entire buffer to context.
---@return nil
function Sllm.add_func_to_ctx()
  local text
  if H.utils.is_mode_visual() then
    text = H.utils.get_visual_selection()
    if text:match('^%s*$') then
      H.notify('[sllm] empty selection.', vim.log.levels.WARN)
      return
    end
  else
    local bufnr = vim.api.nvim_get_current_buf()
    text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    if text:match('^%s*$') then
      H.notify('[sllm] file is empty.', vim.log.levels.WARN)
      return
    end
  end
  H.context_manager.add_function(text)
  H.notify('[sllm] added function to context.', vim.log.levels.INFO)
end

--- Add the current visual selection as a code snippet.
---@return nil
function Sllm.add_sel_to_ctx()
  local text = H.utils.get_visual_selection()
  if text:match('^%s*$') then
    H.notify('[sllm] empty selection.', vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  H.context_manager.add_snip(text, H.utils.get_relpath(H.utils.get_path_of_buffer(bufnr)), vim.bo[bufnr].filetype)
  H.notify('[sllm] added selection to context.', vim.log.levels.INFO)
end

--- Add current buffer diagnostics to context as a snippet.
---@return nil
function Sllm.add_diag_to_ctx()
  local bufnr = vim.api.nvim_get_current_buf()
  local diags = vim.diagnostic.get(bufnr)
  if not diags or #diags == 0 then
    H.notify('[sllm] no diagnostics found in buffer.', vim.log.levels.INFO)
    return
  end
  local lines = {}
  for _, d in ipairs(diags) do
    local msg = d.message:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
    local loc = ('[L%d,C%d]'):format((d.lnum or 0) + 1, (d.col or 0) + 1)
    table.insert(lines, loc .. ' ' .. msg)
  end
  H.context_manager.add_snip(
    'diagnostics:\n' .. table.concat(lines, '\n'),
    H.utils.get_relpath(H.utils.get_path_of_buffer(bufnr)),
    vim.bo[bufnr].filetype
  )
  H.notify('[sllm] added diagnostics to context.', vim.log.levels.INFO)
end

--- Prompt for a shell command, run it, and add its output to context.
---@return nil
function Sllm.add_cmd_out_to_ctx()
  H.input({ prompt = 'Command: ' }, function(cmd_raw)
    H.notify('[sllm] running command: ' .. cmd_raw, vim.log.levels.INFO)
    local res_out = H.job_manager.exec_cmd_capture_output(cmd_raw)
    H.context_manager.add_snip(res_out, 'Command-> ' .. cmd_raw, 'text')
    H.notify('[sllm] added command output to context.', vim.log.levels.INFO)
  end)
end

--- Reset the LLM context (fragments, snippets, tools, functions).
---@return nil
function Sllm.reset_context()
  H.context_manager.reset()
  H.notify('[sllm] context reset.', vim.log.levels.INFO)
end

--- Set the system prompt on-the-fly.
---@return nil
function Sllm.set_system_prompt()
  H.input({ prompt = 'System Prompt: ', default = H.state.system_prompt or '' }, function(user_input)
    if user_input == nil then
      H.notify('[sllm] system prompt not changed.', vim.log.levels.INFO)
      return
    end
    if user_input == '' then
      H.state.system_prompt = nil
      H.notify('[sllm] system prompt cleared.', vim.log.levels.INFO)
    else
      H.state.system_prompt = user_input
      H.notify('[sllm] system prompt updated.', vim.log.levels.INFO)
    end
  end)
end

--- Show available options for the current model.
---@return nil
function Sllm.show_model_options()
  if not H.state.selected_model then
    H.notify('[sllm] no model selected.', vim.log.levels.WARN)
    return
  end

  -- Run `llm models --options -m <model>` to show available options
  local cmd = Sllm.config.llm_cmd .. ' models --options -m ' .. vim.fn.shellescape(H.state.selected_model)
  local output = vim.fn.systemlist(cmd)

  -- Display in a floating window or show in the LLM buffer
  H.ui.show_llm_buffer(Sllm.config.window_type, H.state.selected_model, H.state.online_enabled)
  H.ui.append_to_llm_buffer(
    { '', '> 📋 Available options for ' .. H.state.selected_model, '' },
    Sllm.config.scroll_to_bottom
  )
  H.ui.append_to_llm_buffer(output, Sllm.config.scroll_to_bottom)
  H.ui.append_to_llm_buffer({ '' }, Sllm.config.scroll_to_bottom)
  H.notify('[sllm] showing model options', vim.log.levels.INFO)
end

--- Set or update a model option.
---@return nil
function Sllm.set_model_option()
  H.input({ prompt = 'Option key: ' }, function(key)
    if not key or key == '' then
      H.notify('[sllm] no key provided.', vim.log.levels.INFO)
      return
    end
    H.input({ prompt = 'Option value for "' .. key .. '": ' }, function(value)
      if not value or value == '' then
        H.notify('[sllm] no value provided.', vim.log.levels.INFO)
        return
      end
      -- Try to convert to number if it looks like a number
      local num_value = tonumber(value)
      H.state.model_options[key] = num_value or value
      H.notify('[sllm] set option: ' .. key .. ' = ' .. value, vim.log.levels.INFO)
    end)
  end)
end

--- Reset all model options.
---@return nil
function Sllm.reset_model_options()
  H.state.model_options = {}
  H.notify('[sllm] model options reset.', vim.log.levels.INFO)
end

--- Toggle the online feature (adds/removes online=1 option).
---@return nil
function Sllm.toggle_online()
  H.state.online_enabled = not H.state.online_enabled

  if H.state.online_enabled then
    H.state.model_options.online = 1
    H.notify('[sllm] 🌐 Online mode enabled', vim.log.levels.INFO)
  else
    H.state.model_options.online = nil
    H.notify('[sllm] 📴 Online mode disabled', vim.log.levels.INFO)
  end

  -- Update the UI title to reflect the change
  H.ui.update_llm_win_title(H.state.selected_model, H.state.online_enabled)
end

--- Get online status for UI display.
---@return boolean
function Sllm.is_online_enabled() return H.state.online_enabled end

--- Copy the first code block from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_first_code_block()
  if H.ui.copy_first_code_block() then
    H.notify('[sllm] first code block copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last code block from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_last_code_block()
  if H.ui.copy_last_code_block() then
    H.notify('[sllm] last code block copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last response from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_last_response()
  if H.ui.copy_last_response() then
    H.notify('[sllm] last response copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no response found in LLM buffer.', vim.log.levels.WARN)
  end
end

--- Complete code at cursor position.
---@return nil
function Sllm.complete_code()
  if H.job_manager.is_busy() then
    H.notify('[sllm] already running, please wait.', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1]
  local col = cursor_pos[2]

  -- Get all lines in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Split at cursor: before and after
  local before_lines = {}
  local after_lines = {}

  for i = 1, #lines do
    if i < row then
      table.insert(before_lines, lines[i])
    elseif i == row then
      -- Split the current line at cursor position
      local line = lines[i]
      table.insert(before_lines, line:sub(1, col))
      if col < #line then table.insert(after_lines, line:sub(col + 1)) end
    else
      table.insert(after_lines, lines[i])
    end
  end

  local before_text = table.concat(before_lines, '\n')
  local after_text = table.concat(after_lines, '\n')

  -- Build the completion prompt with cursor marker
  local prompt = [[
    Complete the code at the cursor position marked with <CURSOR>.
    Output ONLY the completion code, no explanations, no markdown formatting.'
  ]]
  prompt = prompt .. before_text .. '<CURSOR>'
  if #after_text > 0 then prompt = prompt .. '\n' .. after_text end

  -- Build LLM command - no continuation, no usage stats for cleaner output
  local cmd = Sllm.config.llm_cmd .. ' --no-stream'
  if H.state.selected_model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(H.state.selected_model) end
  cmd = cmd .. ' ' .. vim.fn.shellescape(prompt)

  H.notify('[sllm] requesting completion...', vim.log.levels.INFO)

  -- Collect the completion output
  local completion_output = {}

  H.job_manager.start(cmd, function(line)
    if line ~= '' then table.insert(completion_output, line) end
  end, function(exit_code)
    if exit_code == 0 and #completion_output > 0 then
      -- Join all output lines
      local completion = table.concat(completion_output, '\n')

      -- Clean up common LLM formatting
      completion = completion:gsub('^```[%w]*\n', '') -- Remove opening code fence
      completion = completion:gsub('\n```$', '') -- Remove closing code fence
      completion = vim.trim(completion)

      if completion ~= '' then
        -- Insert the completion at cursor position
        local completion_lines = vim.split(completion, '\n', { plain = true })

        -- Get the current line and rebuild it with the completion
        local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ''
        local line_before = current_line:sub(1, col)
        local line_after = current_line:sub(col + 1)

        -- Build the new lines to insert
        local new_lines = {}
        if #completion_lines == 1 then
          -- Single line completion
          table.insert(new_lines, line_before .. completion_lines[1] .. line_after)
        else
          -- Multi-line completion
          table.insert(new_lines, line_before .. completion_lines[1])
          for i = 2, #completion_lines - 1 do
            table.insert(new_lines, completion_lines[i])
          end
          table.insert(new_lines, completion_lines[#completion_lines] .. line_after)
        end

        -- Replace the current line with new lines
        vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, new_lines)

        -- Move cursor to end of completion
        local new_row = row + #new_lines - 1
        local new_col = #new_lines[#new_lines] - #line_after
        vim.api.nvim_win_set_cursor(0, { new_row, new_col })

        H.notify('[sllm] completion inserted', vim.log.levels.INFO)
      else
        H.notify('[sllm] received empty completion', vim.log.levels.WARN)
      end
    else
      H.notify('[sllm] completion failed (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
    end
  end)
end

--- Browse chat history, load a conversation, and continue from it.
---@return nil
function Sllm.browse_history()
  local max_entries = Sllm.config.history_max_entries or 1000
  local entries = H.history_manager.fetch_history(Sllm.config.llm_cmd, max_entries)

  if not entries or #entries == 0 then
    H.notify('[sllm] no history found.', vim.log.levels.INFO)
    return
  end

  -- Group entries by conversation
  local conversations = {}
  for _, entry in ipairs(entries) do
    local conv_id = entry.conversation_id
    if conv_id and conv_id ~= '' then
      if not conversations[conv_id] then conversations[conv_id] = {} end
      table.insert(conversations[conv_id], entry)
    end
  end

  -- Build display list
  local conv_data = {}
  for conv_id, conv_entries in pairs(conversations) do
    -- Skip empty conversations or invalid entries
    if #conv_entries > 0 then
      -- Sort entries by timestamp within conversation (oldest first)
      table.sort(conv_entries, function(a, b) return (a.timestamp or '') < (b.timestamp or '') end)

      local first = conv_entries[1]
      -- Ensure first is a valid table (not vim.NIL or nil)
      if first and type(first) == 'table' then
        -- Handle vim.NIL fields by converting to empty string
        local timestamp_raw = first.timestamp
        if type(timestamp_raw) ~= 'string' then timestamp_raw = '' end
        local timestamp = timestamp_raw:gsub('T', ' '):gsub('Z', ''):sub(1, 19)

        local model_raw = first.model
        if type(model_raw) ~= 'string' then model_raw = 'unknown' end
        local model = model_raw

        local prompt_raw = first.prompt
        if type(prompt_raw) ~= 'string' then prompt_raw = '' end
        local prompt = prompt_raw:gsub('\n', ' '):sub(1, 40)
        if #prompt_raw > 40 then prompt = prompt .. '...' end

        table.insert(conv_data, {
          id = conv_id,
          display = string.format('[%s] %s (%d msgs) | %s', timestamp, model, #conv_entries, prompt),
          model = model,
          entries = conv_entries,
        })
      end
    end
  end

  if #conv_data == 0 then
    H.notify('[sllm] no conversations found.', vim.log.levels.INFO)
    return
  end

  -- Sort conversations by timestamp (newest first)
  table.sort(conv_data, function(a, b) return a.display > b.display end)

  local display_list = vim.tbl_map(function(c) return c.display end, conv_data)

  H.pick(display_list, { prompt = 'Select conversation to continue:' }, function(_, idx)
    if not idx then
      H.notify('[sllm] selection canceled.', vim.log.levels.INFO)
      return
    end

    local selected = conv_data[idx]
    if not selected then return end

    -- Update state to continue this conversation
    H.state.selected_model = selected.model
    H.state.continue = selected.id -- Store conversation ID for continuation

    -- Display the conversation
    H.ui.show_llm_buffer(Sllm.config.window_type, selected.model, H.state.online_enabled)
    H.ui.clean_llm_buffer()

    H.ui.append_to_llm_buffer({
      '# Loaded conversation: ' .. selected.id:sub(1, 10) .. '...',
      '*(New prompts will continue this conversation)*',
      '',
    }, Sllm.config.scroll_to_bottom)

    for _, entry in ipairs(selected.entries) do
      local formatted = H.history_manager.format_conversation_entry(entry)
      -- Ensure formatted is a table before appending
      if formatted and type(formatted) == 'table' and #formatted > 0 then
        H.ui.append_to_llm_buffer(formatted, Sllm.config.scroll_to_bottom)
      end
    end

    H.notify('[sllm] loaded ' .. #selected.entries .. ' messages, ready to continue', vim.log.levels.INFO)
  end)
end

return Sllm
