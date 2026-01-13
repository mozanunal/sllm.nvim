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
---     chain_limit = 100,          -- Max conversation chain length
---     ui = {...},                 -- See |Sllm-uiconfig|
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
--- `chain_limit` - Maximum number of chained tool responses to allow. This
--- controls how many times the model can call tools in one go. Default is 100.
--- Set to 0 for unlimited.
---
--- `ui` - Table of UI elements (prompts and headers). See |Sllm-uiconfig|.
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
--- 1. Press `<leader>sl` - Select a template (optional)
--- 2. Press `<leader>ss` - Ask to LLM a question
--- 3. Press `<leader>sa` - Add current file to context
--- 4. Press `<leader>sv` (visual mode) - Add selection to context
--- 5. Press `<leader>sm` - Switch models
--- 6. Press `<leader>sh` - Browse and continue previous conversations
--- 7. Press `<leader><Tab>` - Complete code at cursor position
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
---@toc_entry UIConfig
---@text
---                                                                 *Sllm-uiconfig*
--- # UI configuration ~
---
--- Prompts and headers shown to the user through the Sllm UI. These defaults
--- can be overriden:
--- >lua
---   ui = {
---     ask_llm_prompt = 'Prompt: ',
---     add_url_prompt = 'URL: ',
---     add_cmd_prompt = 'Command: ',
---     markdown_prompt_header = '> 💬 Prompt:',
---     markdown_response_header = '> 🤖 Response',
---     set_system_prompt = 'System Prompt: ',
---     -- Note: markdown headers are used in both live chat and history
---   }
--- <
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
---@field select_template string|false|nil        Keymap for selecting a template.
---@field show_template string|false|nil         Keymap for showing template details.
---@field edit_template string|false|nil          Keymap for editing a template.
---@field clear_template string|false|nil         Keymap for clearing a template.

---@class PreHook
---@field command string                     Shell command to execute.
---@field add_to_context boolean?            Whether to capture stdout and add to context (default: false).

---@class PostHook
---@field command string                     Shell command to execute.

---@class SllmConfig
---@field llm_cmd string                     Command to run the LLM CLI.
---@field default_model string               Default model name or `"default"`.
---@field default_template string?           Default template to use.
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
---@field chain_limit integer?               Maximum number of chained tool responses (default: 100).
---@field ui SllmUIConfig|nil                Prompts and text used in the UI.
---
---@class SllmUIConfig
---@field ask_llm_prompt string              Prompt displayed by the ask_llm function
---@field add_url_prompt string              Prompt displayed by the add_url_to_ctx function
---@field add_cmd_prompt string              Prompt displayed by the add_cmd_out_to_ctx function
---@field markdown_prompt_header string      Text displayed above the user prompt
---@field markdown_response_header string    Text displayed above the LLM response
---@field set_system_prompt string           Prompt displayed when modifying the system prompt
---
-- Module definition ==========================================================
local Sllm = {}
local H = {}

-- Constants ------------------------------------------------------------------
H.ANIMATION_FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

H.PROMPT_TEMPLATE = [[
${user_input}

${snippets}

${files}
]]

H.DEFAULT_CONFIG = vim.deepcopy({
  backend = 'llm',
  backend_config = {
    cmd = 'llm',
  },
  llm_cmd = 'llm', -- Deprecated: use backend_config.cmd instead
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
  chain_limit = 100,
  default_template = nil, -- Default template to use
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
    select_template = '<leader>sl', -- Fuzzy select template (l for list/template)
    show_template = '<leader>sL', -- Show template details
    edit_template = '<leader>si', -- Edit template in editor (i for insert/edit)
    clear_template = '<leader>sI', -- Clear template (capital I)
  },
  ui = {
    ask_llm_prompt = 'Prompt: ',
    add_url_prompt = 'URL: ',
    add_cmd_prompt = 'Command: ',
    markdown_prompt_header = '> 💬 Prompt:',
    markdown_response_header = '> 🤖 Response',
    set_system_prompt = 'System Prompt: ',
  },
})

-- Internal modules
H.backend_registry = require('sllm.backend')
H.backend = nil -- Set during apply_config based on backend selection

-- Internal state
H.state = {
  -- Main state
  continue = nil, -- Can be boolean or conversation_id string
  selected_model = nil,
  system_prompt = nil,
  model_options = {},
  online_enabled = false,
  backend_config = {}, -- Backend-specific configuration
  session_stats = { input = 0, output = 0, cost = 0 }, -- Accumulated token usage

  -- Context
  context = {
    fragments = {},
    snips = {},
    tools = {},
    functions = {},
  },

  -- UI state
  ui = {
    llm_buf = nil,
    animation_timer = nil,
    current_animation_frame_idx = 1,
    is_loading_active = false,
    original_winbar_text = '',
  },

  -- Job state
  job = {
    llm_job_id = nil,
    stdout_acc = '',
  },
}

-- Internal functions for UI
H.notify = vim.notify
H.pick = vim.ui.select
H.input = vim.ui.input

-- Utils helpers -----------------------------------------------------------------
--- Print all elements of `t`, each on its own line separated by "===".
---@param t string[] List of strings to print.
H.utils_print_table = function(t) print(table.concat(t, '\n===')) end

--- Check if a buffer handle is valid.
---@param buf integer? Buffer handle (or `nil`).
---@return boolean
H.utils_buf_is_valid = function(buf) return buf ~= nil and vim.api.nvim_buf_is_valid(buf) end

--- Return `true` if the current mode is any Visual mode (`v`, `V`, or Ctrl+V).
---@return boolean
H.utils_is_mode_visual = function()
  local current_mode = vim.api.nvim_get_mode().mode
  -- \22 is Ctrl-V
  return current_mode:match('^[vV\22]$') ~= nil
end

--- Get text of the current visual selection.
---@return string  The selected text (lines joined with "\n").
H.utils_get_visual_selection = function()
  return table.concat(vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.')), '\n')
end

--- Get the filesystem path of a buffer, or `nil` if it has none.
---@param buf integer Buffer handle.
---@return string?  File path or `nil` if the buffer is unnamed.
H.utils_get_path_of_buffer = function(buf)
  local buf_name = vim.api.nvim_buf_get_name(buf)
  if buf_name == '' then
    return nil
  else
    return buf_name
  end
end

--- Convert an absolute path to one relative to the cwd.
---@param abspath string?  Absolute path (or `nil`).
---@return string?  Relative path if possible; otherwise original or `nil`.
H.utils_get_relpath = function(abspath)
  if abspath == nil then return abspath end
  local cwd = vim.uv.cwd()
  if cwd == nil then return abspath end
  local rel = vim.fs.relpath(cwd, abspath)
  if rel then
    return rel
  else
    return abspath
  end
end

--- Return the window ID showing buffer `buf`, or `nil` if not visible.
---@param buf integer Buffer handle.
---@return integer?  Window ID or `nil`.
H.utils_check_buffer_visible = function(buf)
  if not H.utils_buf_is_valid(buf) then return nil end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then return win end
  end
  return nil
end

--- Simple template renderer: replaces `${key}` with `env[key]`.
---@param tmpl string             Template containing `${var}` placeholders.
---@param env table<string,any>   Lookup table for replacements.
---@return string  Rendered string.
H.utils_render = function(tmpl, env)
  return (tmpl:gsub('%${(.-)}', function(key) return tostring(env[key] or '') end))
end

--- Extract all code blocks from buffer lines.
---@param lines string[]  Buffer lines to parse.
---@return string[]  List of code block contents (without fence markers).
H.utils_extract_code_blocks = function(lines)
  local code_blocks = {}
  local in_code_block = false
  local current_block = {}

  for _, line in ipairs(lines) do
    -- Check for code fence (``` or ~~~)
    if line:match('^```') or line:match('^~~~') then
      if in_code_block then
        -- End of code block
        if #current_block > 0 then table.insert(code_blocks, table.concat(current_block, '\n')) end
        current_block = {}
        in_code_block = false
      else
        -- Start of code block
        in_code_block = true
      end
    elseif in_code_block then
      table.insert(current_block, line)
    end
  end

  -- Handle unclosed code block
  if in_code_block and #current_block > 0 then table.insert(code_blocks, table.concat(current_block, '\n')) end

  return code_blocks
end

--- Remove ANSI escape codes from a string.
---@param text string  The input string possibly containing ANSI escape codes.
---@return string  The string with ANSI escape codes removed.
H.utils_strip_ansi_codes = function(text)
  local ansi_escape_pattern = '[\27\155][][()#;?%][0-9;]*[A-Za-z@^_`{|}~]'
  return text:gsub(ansi_escape_pattern, '')
end

--- Parse JSON string safely with error handling.
---@param json_str string  JSON string to parse.
---@return table?  Parsed table or nil on error.
H.utils_parse_json = function(json_str)
  local ok, result = pcall(vim.fn.json_decode, json_str)
  if ok then
    return result
  else
    return nil
  end
end

-- Job Manager helpers -----------------------------------------------------------
--- Check if a job is currently running.
---@return boolean `true` if a job is active, `false` otherwise.
H.job_is_busy = function() return H.state.job.llm_job_id ~= nil end

---Execute a command synchronously and capture its output.
---@param cmd_raw string Command to execute (supports vim cmd expansion)
---@return string Combined stdout/stderr output, labeled if both present
H.job_exec_cmd_capture_output = function(cmd_raw)
  local cmd = vim.fn.expandcmd(cmd_raw)
  local result = vim.system({ 'bash', '-c', cmd }, { text = true }):wait()
  local res_stdout = vim.trim(result.stdout or '')
  local res_stderr = vim.trim(result.stderr or '')
  local output = ''
  if res_stdout ~= '' then output = output .. '\nstdout:\n' .. res_stdout end
  if res_stderr ~= '' then output = output .. '\nstderr:\n' .. res_stderr end
  return output
end

--- Start a new job and stream its output line by line.
---
--- Splits on `'\n'` in the stdout buffer, strips ANSI codes, and calls
--- `hook_on_stdout_line` for each line. Handles stderr separately via
--- `hook_on_stderr_line`. Once the job exits, it flushes any leftover,
--- clears state, and calls `hook_on_exit`.
---
---@param cmd string|string[]                      Command or command-plus-args for `vim.fn.jobstart`.
---@param hook_on_stdout_line fun(line: string)    Callback invoked on each decoded stdout line.
---@param hook_on_stderr_line fun(line: string)    Callback invoked on each decoded stderr line.
---@param hook_on_exit fun(exit_code: integer)     Callback invoked when the job exits.
---@return nil
H.job_start = function(cmd, hook_on_stdout_line, hook_on_stderr_line, hook_on_exit)
  H.state.job.stdout_acc = ''

  -- Merge current environment with unbuffered settings
  local job_env = vim.fn.environ()
  job_env.PYTHONUNBUFFERED = '1'
  job_env.PYTHONDONTWRITEBYTECODE = '1'

  H.state.job.llm_job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    pty = true, -- Use pty=true for proper streaming (stderr merges into stdout)
    on_stdout = function(_, data, _)
      if not data then return end
      for _, chunk in ipairs(data) do
        if chunk ~= '' then
          -- 1) Accumulate chunks (normalize carriage returns)
          local normalized = chunk:gsub('\r', '\n')
          H.state.job.stdout_acc = H.state.job.stdout_acc .. normalized

          -- 2) Split on '\n' and flush each line
          local nl_pos = H.state.job.stdout_acc:find('\n', 1, true)
          while nl_pos do
            local line = H.state.job.stdout_acc:sub(1, nl_pos - 1)
            local stripped = H.utils_strip_ansi_codes(line)

            -- With pty=true, stderr is merged into stdout
            -- Detect token usage lines and route to stderr handler
            if stripped:match('Token usage:') or stripped:match('^Tool call:') then
              hook_on_stderr_line(stripped)
            else
              hook_on_stdout_line(stripped)
            end

            H.state.job.stdout_acc = H.state.job.stdout_acc:sub(nl_pos + 1)
            nl_pos = H.state.job.stdout_acc:find('\n', 1, true)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      -- With pty=true, stderr is redirected to stdout, so this won't be called much
      -- But keep it for safety
      if not data then return end
      for _, line in ipairs(data) do
        if line ~= '' then hook_on_stderr_line(H.utils_strip_ansi_codes(line)) end
      end
    end,
    on_exit = function(_, exit_code, _)
      -- Flush leftover stdout without a trailing '\n'
      if H.state.job.stdout_acc ~= '' then
        local stdout_acc = H.state.job.stdout_acc:gsub('\r', '\n')
        local nl_pos = stdout_acc:find('\n', 1, true)
        while nl_pos do
          local line = stdout_acc:sub(1, nl_pos - 1)
          local stripped = H.utils_strip_ansi_codes(line)
          if stripped:match('Token usage:') or stripped:match('^Tool call:') then
            hook_on_stderr_line(stripped)
          else
            hook_on_stdout_line(stripped)
          end
          stdout_acc = stdout_acc:sub(nl_pos + 1)
          nl_pos = stdout_acc:find('\n', 1, true)
        end
        if stdout_acc ~= '' then
          local stripped = H.utils_strip_ansi_codes(stdout_acc)
          if stripped:match('Token usage:') or stripped:match('^Tool call:') then
            hook_on_stderr_line(stripped)
          else
            hook_on_stdout_line(stripped)
          end
        end
        H.state.job.stdout_acc = ''
      end
      H.state.job.llm_job_id = nil
      hook_on_exit(exit_code)
    end,
  })
end

--- Stop the currently running job, if any, and reset state.
---@return nil
H.job_stop = function()
  if H.state.job.llm_job_id then
    vim.fn.jobstop(H.state.job.llm_job_id)
    H.state.job.llm_job_id = nil
    H.state.job.stdout_acc = ''
  end
end

-- Context management helpers ------------------------------------------------------
---Reset the context to empty lists.
---@return nil
H.context_reset = function()
  H.state.context = {
    fragments = {},
    snips = {},
    tools = {},
    functions = {},
  }
end

---Add a file path to the fragments list, if not already present.
---@param filepath string  Path to a fragment file.
---@return nil
H.context_add_fragment = function(filepath)
  local is_in_context = vim.tbl_contains(H.state.context.fragments, filepath)
  if not is_in_context then table.insert(H.state.context.fragments, filepath) end
end

---Add a snippet entry to the context.
---@param text string       Snippet text (will be trimmed).
---@param filepath string   Source file path for the snippet.
---@param filetype string   Filetype/language of the snippet.
---@return nil
H.context_add_snip = function(text, filepath, filetype)
  table.insert(H.state.context.snips, {
    filepath = filepath,
    filetype = filetype,
    text = vim.trim(text),
  })
end

---Add a tool name to the tools list, if not already present.
---@param tool_name string  Name of the tool.
---@return nil
H.context_add_tool = function(tool_name)
  local is_in_context = vim.tbl_contains(H.state.context.tools, tool_name)
  if not is_in_context then table.insert(H.state.context.tools, tool_name) end
end

---Add a function representation to the functions list, if not already present.
---@param func_str string   Function source or signature as a string.
---@return nil
H.context_add_function = function(func_str)
  local is_in_context = vim.tbl_contains(H.state.context.functions, func_str)
  if not is_in_context then table.insert(H.state.context.functions, func_str) end
end

---Assemble the full prompt UI, including file list and code snippets.
---@param user_input string?  Optional user input (empty string if `nil`).
---@return string             Trimmed prompt text to send to the LLM.
H.context_render_prompt_ui = function(user_input)
  -- Assemble files section
  local files_list = ''
  if #H.state.context.fragments > 0 then
    files_list = '\n### Fragments\n'
    for _, f in ipairs(H.state.context.fragments) do
      files_list = files_list .. H.utils_render('- ${filepath}', { filepath = H.utils_get_relpath(f) }) .. '\n'
    end
    files_list = files_list .. '\n'
  end

  -- Assemble snippets section
  local snip_list = ''
  if #H.state.context.snips > 0 then
    snip_list = '\n### Snippets\n'
    for _, snip in ipairs(H.state.context.snips) do
      snip_list = snip_list
        .. H.utils_render('From ${filepath}:\n```' .. snip.filetype .. '\n${text}\n```', snip)
        .. '\n\n'
    end
  end

  -- Trim sections
  files_list = vim.trim(files_list)
  snip_list = vim.trim(snip_list)

  -- Render prompt using template
  local prompt = H.utils_render(H.PROMPT_TEMPLATE, {
    user_input = user_input or '',
    snippets = snip_list,
    files = files_list,
  })
  return vim.trim(prompt)
end

-- History helpers ---------------------------------------------------------------
--- Format a history entry for display in a picker.
---@param entry BackendHistoryEntry History entry to format.
---@return string Formatted display string.
H.history_format_entry_for_picker = function(entry)
  local timestamp = entry.timestamp:gsub('T', ' '):gsub('Z', ''):sub(1, 19)
  local prompt_preview = entry.prompt:gsub('\n', ' '):sub(1, 60)
  if #entry.prompt > 60 then prompt_preview = prompt_preview .. '...' end
  return string.format('[%s] %s | %s', timestamp, entry.model, prompt_preview)
end

--- Format a conversation entry for display.
---@param entry BackendHistoryEntry History entry to format.
---@return string[] Lines to display in buffer.
H.history_format_conversation_entry = function(entry)
  local prompt_header = Sllm.config.ui.markdown_prompt_header or '## 💬 Prompt'
  local response_header = Sllm.config.ui.markdown_response_header or '## 🤖 Response'

  local lines = {}
  local timestamp = entry.timestamp:gsub('T', ' '):gsub('Z', '')

  table.insert(lines, string.format('# %s', timestamp))
  table.insert(lines, string.format('**Model:** %s', entry.model))
  table.insert(lines, '')
  table.insert(lines, prompt_header)
  table.insert(lines, '')

  for _, line in ipairs(vim.split(entry.prompt, '\n', { plain = true })) do
    table.insert(lines, line)
  end

  table.insert(lines, '')
  table.insert(lines, response_header)
  table.insert(lines, '')

  for _, line in ipairs(vim.split(entry.response, '\n', { plain = true })) do
    table.insert(lines, line)
  end

  if entry.usage then
    table.insert(lines, '')
    table.insert(lines, '---')
    table.insert(
      lines,
      string.format(
        'Tokens: %s input / %s output',
        entry.usage.prompt_tokens or 'N/A',
        entry.usage.completion_tokens or 'N/A'
      )
    )
  end

  table.insert(lines, '')
  table.insert(lines, '---')
  table.insert(lines, '')

  return lines
end

--- Get unique conversation IDs from history entries.
---@param entries BackendHistoryEntry[] List of history entries.
---@return table<string, integer> Map of conversation_id to count.
H.history_get_conversations = function(entries)
  local conversations = {}
  for _, entry in ipairs(entries) do
    if entry.conversation_id and entry.conversation_id ~= '' then
      conversations[entry.conversation_id] = (conversations[entry.conversation_id] or 0) + 1
    end
  end
  return conversations
end

-- UI helpers --------------------------------------------------------------------
--- Ensure the LLM buffer exists (hidden, markdown) and return its handle.
---@return integer bufnr  Always‐valid buffer handle.
H.ui_ensure_llm_buffer = function()
  if H.state.ui.llm_buf and H.utils_buf_is_valid(H.state.ui.llm_buf) then
    return H.state.ui.llm_buf
  else
    H.state.ui.llm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = H.state.ui.llm_buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = H.state.ui.llm_buf })
    vim.api.nvim_buf_set_name(H.state.ui.llm_buf, 'sllm://chat')
    return H.state.ui.llm_buf
  end
end

--- Compute centered floating‐window options for the LLM buffer.
---@return table<string, number|string>  Options suitable for `nvim_open_win`.
H.ui_create_llm_float_win_opts = function()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.7)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return {
    relative = 'editor',
    row = row > 0 and row or 0,
    col = col > 0 and col or 0,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    zindex = 50,
  }
end

--- Update the winbar of the LLM window if it is visible.
---@param text string  New winbar text.
H.ui_update_winbar = function(text)
  local llm_win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if llm_win and vim.api.nvim_win_is_valid(llm_win) then
    vim.api.nvim_set_option_value('winbar', text, { win = llm_win })
  end
end

--- Create and configure a window for the LLM buffer.
---@return integer win_id      Window handle.
H.ui_create_llm_win = function()
  local window_type = Sllm.config.window_type
  local buf = H.ui_ensure_llm_buffer()

  -- choose window options based on type
  local win_opts
  if window_type == 'float' then
    win_opts = H.ui_create_llm_float_win_opts()
  elseif window_type == 'horizontal' then
    win_opts = { split = 'below' }
  else
    win_opts = { split = 'right' }
  end

  local win_id = vim.api.nvim_open_win(buf, false, win_opts)
  vim.api.nvim_set_option_value('wrap', true, { win = win_id })
  vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
  vim.api.nvim_set_option_value('number', false, { win = win_id })

  H.ui_update_llm_win_title()
  return win_id
end

--- Start the Braille spinner in the LLM window's winbar.
---@return nil
H.ui_start_loading_indicator = function()
  if H.state.ui.is_loading_active then return end
  local llm_win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if not (llm_win and vim.api.nvim_win_is_valid(llm_win)) then return end

  H.state.ui.is_loading_active = true
  H.state.ui.current_animation_frame_idx = 1
  H.state.ui.original_winbar_text = vim.api.nvim_get_option_value('winbar', { win = llm_win })

  if H.state.ui.animation_timer then
    H.state.ui.animation_timer:close()
    H.state.ui.animation_timer = nil
  end
  H.state.ui.animation_timer = vim.loop.new_timer()
  H.state.ui.animation_timer:start(
    0,
    150,
    vim.schedule_wrap(function()
      if not H.state.ui.is_loading_active then
        H.state.ui.animation_timer:stop()
        H.state.ui.animation_timer:close()
        H.state.ui.animation_timer = nil
        return
      end

      local win_check = H.utils_check_buffer_visible(H.state.ui.llm_buf)
      if not (win_check and vim.api.nvim_win_is_valid(win_check)) then
        H.ui_stop_loading_indicator()
        return
      end

      H.state.ui.current_animation_frame_idx = (H.state.ui.current_animation_frame_idx % #H.ANIMATION_FRAMES) + 1
      local frame = H.ANIMATION_FRAMES[H.state.ui.current_animation_frame_idx]
      H.ui_update_winbar(frame .. ' ' .. H.state.ui.original_winbar_text)
    end)
  )
end

--- Stop the loading spinner and restore the original winbar text.
---@return nil
H.ui_stop_loading_indicator = function()
  if not H.state.ui.is_loading_active then return end
  H.state.ui.is_loading_active = false
  if H.state.ui.animation_timer then
    H.state.ui.animation_timer:stop()
    H.state.ui.animation_timer:close()
    H.state.ui.animation_timer = nil
  end
  if H.state.ui.original_winbar_text ~= '' then H.ui_update_winbar(' ' .. H.state.ui.original_winbar_text) end
  H.state.ui.original_winbar_text = ''
end

--- Clear the LLM buffer and stop any active loading animation.
---@return nil
H.ui_clean_llm_buffer = function()
  if H.state.ui.is_loading_active then H.ui_stop_loading_indicator() end
  if H.state.ui.llm_buf and H.utils_buf_is_valid(H.state.ui.llm_buf) then
    vim.api.nvim_buf_set_lines(H.state.ui.llm_buf, 0, -1, false, {})
  end
end

--- Show the LLM buffer, creating a window if needed.
---@return integer win_id  Window handle where the buffer is shown.
H.ui_show_llm_buffer = function()
  local win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if win then
    return win
  else
    return H.ui_create_llm_win()
  end
end

--- Focus (enter) the LLM window, creating it if necessary.
---@return nil
H.ui_focus_llm_buffer = function()
  local win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if win then
    vim.api.nvim_set_current_win(win)
  else
    win = H.ui_show_llm_buffer()
    vim.api.nvim_set_current_win(win)
  end
end

--- Toggle the LLM window: close if open, open if closed.
---@return nil
H.ui_toggle_llm_buffer = function()
  local win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if win then
    vim.api.nvim_win_close(win, false)
  else
    H.ui_show_llm_buffer()
  end
end

--- Append lines to the end of the LLM buffer and scroll to bottom.
---@param lines string[]  Lines to append.
---@return nil
H.ui_append_to_llm_buffer = function(lines)
  if not lines then return end
  local buf = H.ui_ensure_llm_buffer()
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  local win = H.utils_check_buffer_visible(buf)
  if win and Sllm.config.scroll_to_bottom then
    local last = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { last, 0 })
  end
end

--- Update the LLM window's title (winbar) with current model and online status.
---@return nil
H.ui_update_llm_win_title = function()
  local model = H.state.selected_model or '(default)'
  -- Extract only the last part after '/' (e.g., "openai/gpt-4" -> "gpt-4")
  local display = model:match('([^/]+)$') or model
  local online_indicator = H.state.online_enabled and ' 🌐' or ''
  local title = string.format('%s%s', display, online_indicator)
  if H.state.ui.is_loading_active then
    H.state.ui.original_winbar_text = title
    -- Update the current display with animation frame
    local frame = H.ANIMATION_FRAMES[H.state.ui.current_animation_frame_idx]
    H.ui_update_winbar(frame .. ' ' .. title)
  else
    H.ui_update_winbar(' ' .. title)
  end
end

--- Format number in k format (e.g., 0.14k for 140).
---@param num number  The number to format.
---@return string  Formatted string.
local format_k = function(num)
  if num >= 1000 then
    return string.format('%.2fk', num / 1000)
  else
    return string.format('%d', num)
  end
end

--- Update the winbar to show accumulated session statistics.
---@param stats table  Table with `input`, `output`, and `cost` fields.
---@return nil
H.ui_update_session_stats = function(stats)
  local llm_win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if not (llm_win and vim.api.nvim_win_is_valid(llm_win)) then return end

  -- Get base title (just model name)
  local base_title
  if H.state.ui.original_winbar_text ~= '' then
    base_title = H.state.ui.original_winbar_text
  else
    local model = H.state.selected_model or '(default)'
    -- Extract only the last part after '/' (e.g., "openai/gpt-4" -> "gpt-4")
    local display = model:match('([^/]+)$') or model
    base_title = string.format('%s%s', display, H.state.online_enabled and ' 🌐' or '')
  end

  -- Remove any existing stats section from base title
  base_title = base_title:match('^(.-)%s*|') or base_title

  -- Format stats: ⬇️ input ⬆️ output $ cost
  local stats_text = string.format(' | ⬇️ %s ⬆️ %s $ %.2f',
    format_k(stats.input), format_k(stats.output), stats.cost)

  -- Update the title with stats
  local new_title = base_title .. stats_text

  if H.state.ui.is_loading_active then
    H.state.ui.original_winbar_text = new_title
  else
    H.ui_update_winbar(' ' .. new_title)
  end
end

--- Copy the first code block from the LLM buffer to the clipboard.
---@return boolean  `true` if a code block was found and copied; `false` otherwise.
H.ui_copy_first_code_block = function()
  local buf = H.ui_ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code_blocks = H.utils_extract_code_blocks(lines)

  if #code_blocks == 0 then return false end

  vim.fn.setreg('+', code_blocks[1])
  vim.fn.setreg('"', code_blocks[1])
  return true
end

--- Copy the last code block from the LLM buffer to the clipboard.
---@return boolean  `true` if a code block was found and copied; `false` otherwise.
H.ui_copy_last_code_block = function()
  local buf = H.ui_ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code_blocks = H.utils_extract_code_blocks(lines)

  if #code_blocks == 0 then return false end

  vim.fn.setreg('+', code_blocks[#code_blocks])
  vim.fn.setreg('"', code_blocks[#code_blocks])
  return true
end

--- Copy the last response from the LLM buffer to the clipboard.
--- Extracts content from the last response marker to the end.
---@return boolean  `true` if content was copied; `false` if no response found.
H.ui_copy_last_response = function()
  local response_header = Sllm.config.ui.markdown_response_header or '> 🤖 Response'
  local buf = H.ui_ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  if #lines == 0 then return false end

  -- Find the last occurrence of the response marker
  local last_response_idx = nil
  for i = #lines, 1, -1 do
    if lines[i]:match('^' .. vim.pesc(response_header)) then
      last_response_idx = i
      break
    end
  end

  if not last_response_idx then return false end

  -- Extract from the response marker to the end (skip the marker line and empty lines)
  local response_lines = {}
  for i = last_response_idx + 1, #lines do
    table.insert(response_lines, lines[i])
  end

  -- Remove leading empty lines
  while #response_lines > 0 and response_lines[1]:match('^%s*$') do
    table.remove(response_lines, 1)
  end

  -- Remove trailing empty lines
  while #response_lines > 0 and response_lines[#response_lines]:match('^%s*$') do
    table.remove(response_lines)
  end

  if #response_lines == 0 then return false end

  local content = table.concat(response_lines, '\n')
  vim.fn.setreg('+', content)
  vim.fn.setreg('"', content)
  return true
end

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
Sllm.config = vim.deepcopy(H.DEFAULT_CONFIG)
--minidoc_afterlines_end

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  vim.validate({ config = { config, 'table', true } })
  config = vim.tbl_deep_extend('force', vim.deepcopy(H.DEFAULT_CONFIG), config or {})
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
      select_template = { modes = { 'n', 'v' }, func = Sllm.select_template, desc = 'Select template' },
      show_template = { modes = { 'n', 'v' }, func = Sllm.show_template, desc = 'Show template details' },
      edit_template = { modes = { 'n', 'v' }, func = Sllm.edit_template, desc = 'Edit template' },
      clear_template = { modes = { 'n', 'v' }, func = Sllm.clear_template, desc = 'Clear template' },
    }

    for name, def in pairs(keymap_defs) do
      local key = km[name]
      if type(key) == 'string' and key ~= '' then vim.keymap.set(def.modes, key, def.func, { desc = def.desc }) end
    end
  end

  -- Set up backend
  local backend_name = Sllm.config.backend or 'llm'
  H.backend = H.backend_registry.get(backend_name)
  if not H.backend then
    error(
      string.format(
        '[sllm] Backend "%s" not found. Available: %s',
        backend_name,
        table.concat(H.backend_registry.list(), ', ')
      )
    )
  end

  -- Set up backend config (with backward compatibility for llm_cmd)
  H.state.backend_config = Sllm.config.backend_config or {}
  if Sllm.config.llm_cmd and Sllm.config.llm_cmd ~= 'llm' then
    -- User specified llm_cmd directly (deprecated), use it
    H.state.backend_config.cmd = Sllm.config.llm_cmd
  end

  H.state.continue = not Sllm.config.on_start_new_chat
  H.state.selected_model = Sllm.config.default_model ~= 'default' and Sllm.config.default_model
    or H.backend.get_default_model(H.state.backend_config)
  H.state.system_prompt = Sllm.config.system_prompt
  H.state.model_options = Sllm.config.model_options or {}
  H.state.online_enabled = Sllm.config.online_enabled or false
  H.state.selected_template = Sllm.config.default_template or nil

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
  if H.utils_is_mode_visual() then Sllm.add_sel_to_ctx() end
  H.input({ prompt = Sllm.config.ui.ask_llm_prompt }, function(user_input)
    if user_input == '' then
      H.notify('[sllm] no prompt provided.', vim.log.levels.INFO)
      return
    end
    if user_input == nil then
      H.notify('[sllm] prompt canceled.', vim.log.levels.INFO)
      return
    end

    H.ui_show_llm_buffer()
    if H.job_is_busy() then
      H.notify('[sllm] already running, please wait.', vim.log.levels.WARN)
      return
    end

    if Sllm.config.pre_hooks then
      for _, hook in ipairs(Sllm.config.pre_hooks) do
        local output = H.job_exec_cmd_capture_output(hook.command)
        if hook.add_to_context then
          H.context_add_snip(output, 'Pre-hook-> ' .. hook.command, 'text')
          H.notify('[sllm] pre-hook executed, added to context ' .. hook.command, vim.log.levels.INFO)
        end
      end
    end

    local ctx = H.state.context
    local prompt = H.context_render_prompt_ui(user_input)
    H.ui_append_to_llm_buffer({ '', Sllm.config.ui.markdown_prompt_header, '' })
    H.ui_append_to_llm_buffer(vim.split(prompt, '\n', { plain = true }))
    H.ui_start_loading_indicator()

    local cmd = H.backend.build_command(H.state.backend_config, {
      prompt = prompt,
      continue = H.state.continue,
      show_usage = Sllm.config.show_usage,
      model = H.state.selected_model,
      ctx_files = ctx.fragments,
      tools = ctx.tools,
      functions = ctx.functions,
      system_prompt = H.state.system_prompt,
      model_options = H.state.model_options,
      chain_limit = Sllm.config.chain_limit,
      template = H.state.selected_template,
    })
    H.state.continue = true

    local first_line = false
    H.job_start(
      cmd,
      -- stdout handler: display LLM response
      ---@param line string
      function(line)
        if not first_line then
          H.ui_stop_loading_indicator()
          H.ui_append_to_llm_buffer({ '', Sllm.config.ui.markdown_response_header, '' })
          first_line = true
        end
        H.ui_append_to_llm_buffer({ line })
      end,
      -- stderr handler: parse token usage and filter tool calls
      ---@param line string
      function(line)
        -- Parse token usage and accumulate stats
        local usage = H.backend.parse_token_usage(line)
        if usage then
          H.state.session_stats.input = H.state.session_stats.input + usage.input
          H.state.session_stats.output = H.state.session_stats.output + usage.output
          H.state.session_stats.cost = H.state.session_stats.cost + usage.cost
          if Sllm.config.show_usage then H.ui_update_session_stats(H.state.session_stats) end
          return
        end

        -- Filter out tool call outputs (they can be very large)
        if H.backend.is_tool_call_output(line) then return end

        -- Display other stderr lines if they're not filtered
        if line ~= '' then H.ui_append_to_llm_buffer({ line }) end
      end,
      -- exit handler
      ---@param exit_code integer
      function(exit_code)
        H.ui_stop_loading_indicator()
        if not first_line then
          H.ui_append_to_llm_buffer({ '', Sllm.config.ui.markdown_response_header, '' })
          local msg = exit_code == 0 and '(empty response)' or string.format('(failed or canceled: exit %d)', exit_code)
          H.ui_append_to_llm_buffer({ msg })
        end
        H.notify('[sllm] done ✅ exit code: ' .. exit_code, vim.log.levels.INFO)
        H.ui_append_to_llm_buffer({ '' })
        if Sllm.config.reset_ctx_each_prompt then H.context_reset() end
        if Sllm.config.post_hooks then
          for _, hook in ipairs(Sllm.config.post_hooks) do
            local _ = H.job_exec_cmd_capture_output(hook.command)
          end
        end
      end
    )
  end)
end

--- Cancel the in-flight LLM request, if any.
---@return nil
function Sllm.cancel()
  if H.job_is_busy() then
    H.job_stop()
    H.notify('[sllm] canceling request...', vim.log.levels.WARN)
  else
    H.notify('[sllm] no active llm job', vim.log.levels.INFO)
  end
end

--- Start a new chat (clears buffer and state).
---@return nil
function Sllm.new_chat()
  if H.job_is_busy() then
    H.job_stop()
    H.notify('[sllm] previous request canceled for new chat.', vim.log.levels.INFO)
  end
  H.state.continue = false
  H.state.session_stats = { input = 0, output = 0, cost = 0 } -- Reset stats for new chat
  H.ui_show_llm_buffer()
  H.ui_clean_llm_buffer()
  H.notify('[sllm] new chat created', vim.log.levels.INFO)
end

--- Focus the existing LLM window or create it.
---@return nil
function Sllm.focus_llm_buffer() H.ui_focus_llm_buffer() end

--- Toggle visibility of the LLM window.
---@return nil
function Sllm.toggle_llm_buffer() H.ui_toggle_llm_buffer() end

--- Prompt user to select an LLM model.
---@return nil
function Sllm.select_model()
  local models = H.backend.get_models(H.state.backend_config)
  if not (models and #models > 0) then
    H.notify('[sllm] no models found.', vim.log.levels.ERROR)
    return
  end
  H.pick(models, {}, function(item)
    if item then
      H.state.selected_model = item
      H.notify('[sllm] selected model: ' .. item, vim.log.levels.INFO)
      H.ui_update_llm_win_title()
    else
      H.notify('[sllm] llm model not changed', vim.log.levels.WARN)
    end
  end)
end

--- Add a tool to the current context.
---@return nil
function Sllm.add_tool_to_ctx()
  local tools = H.backend.get_tools(H.state.backend_config)
  if not (tools and #tools > 0) then
    H.notify('[sllm] no tools found.', vim.log.levels.ERROR)
    return
  end
  H.pick(tools, {}, function(item)
    if item then
      H.context_add_tool(item)
      H.notify('[sllm] tool added: ' .. item, vim.log.levels.INFO)
    else
      H.notify('[sllm] no tools added.', vim.log.levels.WARN)
    end
  end)
end

--- Add the current file (or URL) path to the context.
---@return nil
function Sllm.add_file_to_ctx()
  local buf_path = H.utils_get_path_of_buffer(0)
  if buf_path then
    H.context_add_fragment(buf_path)
    H.notify('[sllm] context +' .. H.utils_get_relpath(buf_path), vim.log.levels.INFO)
  else
    H.notify('[sllm] buffer does not have a path.', vim.log.levels.WARN)
  end
end

--- Prompt user for a URL and add it to context.
---@return nil
function Sllm.add_url_to_ctx()
  H.input({ prompt = Sllm.config.ui.add_url_prompt }, function(user_input)
    if user_input == '' then
      H.notify('[sllm] no URL provided.', vim.log.levels.INFO)
      return
    end
    H.context_add_fragment(user_input)
    H.notify('[sllm] URL added to context: ' .. user_input, vim.log.levels.INFO)
  end)
end

--- Add the current function or entire buffer to context.
---@return nil
function Sllm.add_func_to_ctx()
  local text
  if H.utils_is_mode_visual() then
    text = H.utils_get_visual_selection()
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
  H.context_add_function(text)
  H.notify('[sllm] added function to context.', vim.log.levels.INFO)
end

--- Add the current visual selection as a code snippet.
---@return nil
function Sllm.add_sel_to_ctx()
  local text = H.utils_get_visual_selection()
  if text:match('^%s*$') then
    H.notify('[sllm] empty selection.', vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  H.context_add_snip(text, H.utils_get_relpath(H.utils_get_path_of_buffer(bufnr)), vim.bo[bufnr].filetype)
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
  H.context_add_snip(
    'diagnostics:\n' .. table.concat(lines, '\n'),
    H.utils_get_relpath(H.utils_get_path_of_buffer(bufnr)),
    vim.bo[bufnr].filetype
  )
  H.notify('[sllm] added diagnostics to context.', vim.log.levels.INFO)
end

--- Prompt for a shell command, run it, and add its output to context.
---@return nil
function Sllm.add_cmd_out_to_ctx()
  H.input({ prompt = Sllm.config.ui.add_cmd_prompt }, function(cmd_raw)
    H.notify('[sllm] running command: ' .. cmd_raw, vim.log.levels.INFO)
    local res_out = H.job_exec_cmd_capture_output(cmd_raw)
    H.context_add_snip(res_out, 'Command-> ' .. cmd_raw, 'text')
    H.notify('[sllm] added command output to context.', vim.log.levels.INFO)
  end)
end

--- Reset the LLM context (fragments, snippets, tools, functions).
---@return nil
function Sllm.reset_context()
  H.context_reset()
  H.notify('[sllm] context reset.', vim.log.levels.INFO)
end

--- Set the system prompt on-the-fly.
---@return nil
function Sllm.set_system_prompt()
  H.input({ prompt = Sllm.config.ui.set_system_prompt, default = H.state.system_prompt or '' }, function(user_input)
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
  local llm_cmd = H.state.backend_config.cmd or 'llm'
  local cmd = llm_cmd .. ' models --options -m ' .. vim.fn.shellescape(H.state.selected_model)
  local output = vim.fn.systemlist(cmd)

  -- Display in a floating window or show in the LLM buffer
  H.ui_show_llm_buffer()
  H.ui_append_to_llm_buffer(
    { '', '> 📋 Available options for ' .. H.state.selected_model, '' },
    Sllm.config.scroll_to_bottom
  )
  H.ui_append_to_llm_buffer(output)
  H.ui_append_to_llm_buffer({ '' })
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
  H.ui_update_llm_win_title()
end

--- Get online status for UI display.
---@return boolean
function Sllm.is_online_enabled() return H.state.online_enabled end

--- Copy the first code block from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_first_code_block()
  if H.ui_copy_first_code_block() then
    H.notify('[sllm] first code block copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last code block from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_last_code_block()
  if H.ui_copy_last_code_block() then
    H.notify('[sllm] last code block copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last response from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_last_response()
  if H.ui_copy_last_response() then
    H.notify('[sllm] last response copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no response found in LLM buffer.', vim.log.levels.WARN)
  end
end

--- Complete code at cursor position.
---@return nil
function Sllm.complete_code()
  if H.job_is_busy() then
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
  local llm_cmd = H.state.backend_config.cmd or 'llm'
  local cmd = llm_cmd .. ' --no-stream'
  if H.state.selected_model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(H.state.selected_model) end
  cmd = cmd .. ' ' .. vim.fn.shellescape(prompt)

  H.notify('[sllm] requesting completion...', vim.log.levels.INFO)

  -- Collect the completion output
  local completion_output = {}

  H.job_start(cmd, function(line)
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
  if not H.backend.supports_history() then
    H.notify('[sllm] current backend does not support history.', vim.log.levels.WARN)
    return
  end

  local max_entries = Sllm.config.history_max_entries or 1000
  local entries = H.backend.get_history(H.state.backend_config, { count = max_entries })

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
    H.ui_show_llm_buffer()
    H.ui_clean_llm_buffer()

    H.ui_append_to_llm_buffer({
      '# Loaded conversation: ' .. selected.id:sub(1, 10) .. '...',
      '*(New prompts will continue this conversation)*',
      '',
    })

    for _, entry in ipairs(selected.entries) do
      local formatted = H.history_format_conversation_entry(entry)
      -- Ensure formatted is a table before appending
      if formatted and type(formatted) == 'table' and #formatted > 0 then H.ui_append_to_llm_buffer(formatted) end
    end

    H.notify('[sllm] loaded ' .. #selected.entries .. ' messages, ready to continue', vim.log.levels.INFO)
  end)
end

--- Select a template to use for future prompts.
---@return nil
function Sllm.select_template()
  local templates = H.backend.get_templates(H.state.backend_config)
  if not (templates and #templates > 0) then
    H.notify('[sllm] no templates found.', vim.log.levels.INFO)
    return
  end

  H.pick(templates, { prompt = 'Select template:', default = H.state.selected_template }, function(item)
    if item then
      H.state.selected_template = item
      H.notify('[sllm] template selected: ' .. item, vim.log.levels.INFO)
    else
      H.notify('[sllm] template not changed', vim.log.levels.WARN)
    end
  end)
end

--- Show details of the currently selected template or select one to show.
---@return nil
function Sllm.show_template()
  local templates = H.backend.get_templates(H.state.backend_config)
  if not (templates and #templates > 0) then
    H.notify('[sllm] no templates found.', vim.log.levels.INFO)
    return
  end

  local template_name = H.state.selected_template
  if not template_name or not vim.tbl_contains(templates, template_name) then
    H.pick(templates, { prompt = 'Select template to show:', default = template_name }, function(item)
      if item then
        H.show_template_content(item)
      else
        H.notify('[sllm] no template selected', vim.log.levels.WARN)
      end
    end)
  else
    H.show_template_content(template_name)
  end
end

H.show_template_content = function(template_name)
  local template = H.backend.get_template(H.state.backend_config, template_name)
  if not template then
    H.notify('[sllm] template not found: ' .. template_name, vim.log.levels.ERROR)
    return
  end

  H.ui_show_llm_buffer()
  H.ui_append_to_llm_buffer({ '', '> 📋 Template: ' .. template.name, '' })
  H.ui_append_to_llm_buffer(vim.split(template.content, '\n', { plain = true }))
  H.ui_append_to_llm_buffer({ '' })
  H.notify('[sllm] showing template: ' .. template.name, vim.log.levels.INFO)
end

--- Edit the currently selected template in your editor.
---@return nil
function Sllm.edit_template()
  if not H.state.selected_template then
    H.notify('[sllm] no template selected.', vim.log.levels.WARN)
    return
  end

  local success = H.backend.edit_template(H.state.backend_config, H.state.selected_template)
  if success then
    H.notify('[sllm] template edited: ' .. H.state.selected_template, vim.log.levels.INFO)
  else
    H.notify('[sllm] failed to edit template: ' .. H.state.selected_template, vim.log.levels.ERROR)
  end
end

--- Clear the selected template.
---@return nil
function Sllm.clear_template()
  H.state.selected_template = nil
  H.notify('[sllm] template cleared', vim.log.levels.INFO)
end

return Sllm
