-- sllm.nvim core module
-- Wraps Simon Willison's llm CLI for Neovim.

---@class SllmKeymaps
---@field ask string|false|nil             Keymap for asking the LLM.
---@field select_model string|false|nil    Keymap for selecting an LLM model.
---@field select_mode string|false|nil     Keymap for selecting a mode/template.
---@field add_context string|false|nil     Keymap for adding file (normal) or selection (visual).
---@field commands string|false|nil        Keymap for opening the command picker.
---@field new_chat string|false|nil        Keymap for starting a new chat.
---@field cancel string|false|nil          Keymap for canceling a request.
---@field toggle_buffer string|false|nil   Keymap for toggling the LLM window.
---@field history string|false|nil         Keymap for browsing chat history.
---@field copy_code string|false|nil       Keymap for copying the last code block.
---@field complete string|false|nil        Keymap for triggering code completion at cursor.

---@class PreHook
---@field command string                     Shell command to execute.
---@field add_to_context boolean?            Whether to capture stdout and add to context (default: false).

---@class PostHook
---@field command string                     Shell command to execute.

---@class SllmConfig
---@field llm_cmd string?                    Command or path to the LLM CLI (default: "llm").
--- Legacy: previously `backend_config.cmd` (deprecated)
---@field default_model string               Default model name or `"default"`.
---@field default_mode string?               Default mode/template to use on startup.
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
---@field online_enabled boolean?            Enable online/web mode by default.
---@field history_max_entries integer?       Maximum number of history entries to fetch (default: 1000).
---@field chain_limit integer?               Maximum number of chained tool responses (default: 100).
---@field ui SllmUIConfig|nil                Prompts and text used in the UI.
---
---@class SllmUIConfig
---@field show_usage boolean                 Show token usage stats after responses.
---@field ask_llm_prompt string              Prompt displayed by the ask_llm function
---@field add_url_prompt string              Prompt displayed by the add_url_to_ctx function
---@field add_cmd_prompt string              Prompt displayed by the add_cmd_out_to_ctx function
---@field markdown_prompt_header string      Text displayed above the user prompt
---@field markdown_response_header string    Text displayed above the LLM response
---
-- Module definition ==========================================================
local Sllm = {}
local H = {}

-- Constants ------------------------------------------------------------------
H.ANIMATION_FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
H.WINBAR_DEBOUNCE_MS = 50

-- Keymap definitions (name -> {modes, func_name, desc})
-- func_name is resolved to Sllm[func_name] during apply_config
H.KEYMAP_DEFS = {
  ask = { modes = { 'n', 'v' }, func_name = 'ask_llm', desc = 'Ask LLM' },
  select_model = { modes = { 'n', 'v' }, func_name = 'select_model', desc = 'Select model' },
  select_mode = { modes = { 'n', 'v' }, func_name = 'select_mode', desc = 'Select mode/template' },
  add_context = { modes = { 'n', 'v' }, func_name = 'add_context', desc = 'Add file/selection to context' },
  commands = { modes = { 'n', 'v' }, func_name = 'run_command', desc = 'Command picker' },
  new_chat = { modes = { 'n', 'v' }, func_name = 'new_chat', desc = 'New chat' },
  cancel = { modes = { 'n', 'v' }, func_name = 'cancel', desc = 'Cancel request' },
  toggle_buffer = { modes = { 'n', 'v' }, func_name = 'toggle_llm_buffer', desc = 'Toggle LLM buffer' },
  history = { modes = { 'n', 'v' }, func_name = 'browse_history', desc = 'Browse chat history' },
  copy_code = { modes = { 'n', 'v' }, func_name = 'copy_last_code_block', desc = 'Copy last code block' },
  complete = { modes = { 'n', 'v' }, func_name = 'complete_code', desc = 'Complete code at cursor' },
}

-- Command registry for unified command picker
-- Each command: { cmd, desc, action (function or func_name string), category }
H.COMMANDS = {
  -- Chat
  { cmd = 'new', desc = 'Start new chat', action = 'new_chat', category = 'Chat' },
  { cmd = 'history', desc = 'Browse chat history', action = 'browse_history', category = 'Chat' },
  { cmd = 'cancel', desc = 'Cancel current request', action = 'cancel', category = 'Chat' },
  -- Context
  { cmd = 'add-file', desc = 'Add current file', action = 'add_file_to_ctx', category = 'Context' },
  { cmd = 'add-url', desc = 'Add URL content', action = 'add_url_to_ctx', category = 'Context' },
  { cmd = 'add-selection', desc = 'Add visual selection', action = 'add_sel_to_ctx', category = 'Context' },
  { cmd = 'add-diagnostics', desc = 'Add buffer diagnostics', action = 'add_diag_to_ctx', category = 'Context' },
  { cmd = 'add-output', desc = 'Add shell command output', action = 'add_cmd_out_to_ctx', category = 'Context' },
  { cmd = 'add-tool', desc = 'Add llm tool', action = 'add_tool_to_ctx', category = 'Context' },
  { cmd = 'add-function', desc = 'Add Python function', action = 'add_func_to_ctx', category = 'Context' },
  { cmd = 'clear-context', desc = 'Reset all context', action = 'reset_context', category = 'Context' },
  -- Model
  { cmd = 'model', desc = 'Switch model', action = 'select_model', category = 'Model' },
  { cmd = 'template', desc = 'Switch template', action = 'select_mode', category = 'Model' },
  { cmd = 'online', desc = 'Toggle online mode', action = 'toggle_online', category = 'Model' },
  { cmd = 'system', desc = 'Set system prompt', action = 'set_system_prompt', category = 'Model' },
  -- Options
  { cmd = 'options', desc = 'Show model options', action = 'show_model_options', category = 'Options' },
  { cmd = 'set-option', desc = 'Set model option', action = 'set_model_option', category = 'Options' },
  { cmd = 'reset-options', desc = 'Reset model options', action = 'reset_model_options', category = 'Options' },
  -- Template
  { cmd = 'template-show', desc = 'Show template content', action = 'show_template', category = 'Template' },
  { cmd = 'template-edit', desc = 'Edit template file', action = 'edit_template', category = 'Template' },
  -- Copy
  { cmd = 'copy-code', desc = 'Copy last code block', action = 'copy_last_code_block', category = 'Copy' },
  { cmd = 'copy-code-first', desc = 'Copy first code block', action = 'copy_first_code_block', category = 'Copy' },
  { cmd = 'copy-response', desc = 'Copy last response', action = 'copy_last_response', category = 'Copy' },
  -- UI
  { cmd = 'focus', desc = 'Focus LLM window', action = 'focus_llm_buffer', category = 'UI' },
  { cmd = 'toggle', desc = 'Toggle LLM buffer', action = 'toggle_llm_buffer', category = 'UI' },
}

H.PROMPT_TEMPLATE = [[
${user_input}

${snippets}

${files}
]]

H.DEFAULT_CONFIG = vim.deepcopy({
  llm_cmd = 'llm',
  default_model = 'default',
  default_mode = 'sllm_chat', -- Default mode/template to use on startup
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
  debug = false, -- Show LLM commands in buffer for debugging
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
    show_usage = true, -- Show token usage stats after responses
    ask_llm_prompt = 'Prompt: ',
    add_url_prompt = 'URL: ',
    add_cmd_prompt = 'Command: ',
    markdown_prompt_header = '> 💬 Prompt:',
    markdown_response_header = '> 🤖 Response',
    set_system_prompt = 'System Prompt: ',
  },
})

-- Internal modules
H.backend = require('sllm.backend.llm')

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
    winbar_debounce_timer = nil,
  },

  -- Loading indicator state machine
  loading = {
    active = false,
    timer = nil,
    frame_idx = 1,
  },

  -- Job state
  job = {
    llm_job_id = nil,
    stdout_acc = '',
    in_tool_output = false, -- Track if we're inside tool output block
  },
}

-- Internal functions for UI
H.notify = vim.notify
H.pick = vim.ui.select
H.input = vim.ui.input

-- Utils helpers -----------------------------------------------------------------
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

--- Get the valid LLM window, or nil if not visible/valid.
---@return integer?  Window ID or nil.
H.utils_get_llm_win = function()
  local win = H.utils_check_buffer_visible(H.state.ui.llm_buf)
  if win and vim.api.nvim_win_is_valid(win) then return win end
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

--- Format number in k format (e.g., 0.14k for 140).
---@param num number  The number to format.
---@return string  Formatted string.
H.utils_format_k = function(num)
  if num >= 1000 then
    return string.format('%.2fk', num / 1000)
  else
    return string.format('%d', num)
  end
end

--- Extract model display name (last part after '/').
---@param model string?  Full model name (e.g., "openai/gpt-4").
---@return string  Display name (e.g., "gpt-4").
H.utils_get_model_display_name = function(model)
  model = model or '(default)'
  return model:match('([^/]+)$') or model
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
  H.state.job.in_tool_output = false

  -- Helper to route a line to the appropriate handler with tool output state tracking
  local function route_line(stripped)
    -- Token usage always goes to stderr
    if stripped:match('Token usage:') then
      H.state.job.in_tool_output = false
      hook_on_stderr_line(stripped)
      return
    end

    -- Tool call header: show it and enter tool output mode
    if stripped:match('^Tool call:') then
      H.state.job.in_tool_output = true
      hook_on_stderr_line(stripped)
      return
    end

    -- If we're in tool output mode, check if this line is tool output
    if H.state.job.in_tool_output then
      -- Indented lines are tool output - send to stderr (will be filtered)
      if stripped:match('^%s+') or stripped == '' then
        hook_on_stderr_line(stripped)
        return
      end
      -- Non-indented, non-empty line: exit tool output mode
      H.state.job.in_tool_output = false
    end

    -- Regular output goes to stdout
    hook_on_stdout_line(stripped)
  end

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
            route_line(stripped)
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
          route_line(stripped)
          stdout_acc = stdout_acc:sub(nl_pos + 1)
          nl_pos = stdout_acc:find('\n', 1, true)
        end
        if stdout_acc ~= '' then
          local stripped = H.utils_strip_ansi_codes(stdout_acc)
          route_line(stripped)
        end
        H.state.job.stdout_acc = ''
      end
      H.state.job.llm_job_id = nil
      H.state.job.in_tool_output = false
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

--- Internal: Actually render the winbar (called by debounced version).
---@return nil
H.ui_render_winbar_impl = function()
  local llm_win = H.utils_get_llm_win()
  if not llm_win then return end

  local parts = {}

  -- 1. Loading indicator or space
  if H.state.loading.active then
    table.insert(parts, H.ANIMATION_FRAMES[H.state.loading.frame_idx] .. ' ')
  else
    table.insert(parts, '  ')
  end

  -- 2. Model name
  table.insert(parts, H.utils_get_model_display_name(H.state.selected_model))

  -- 3. Template/mode name (if set)
  if H.state.selected_template then table.insert(parts, ' [' .. H.state.selected_template .. ']') end

  -- 4. Online indicator
  if H.state.online_enabled then table.insert(parts, ' 🌐') end

  -- 4. Stats (if available)
  local stats = H.state.session_stats
  if stats.input > 0 or stats.output > 0 or stats.cost > 0 then
    table.insert(
      parts,
      string.format(
        ' | ⬇️ %s ⬆️ %s $ %.2f',
        H.utils_format_k(stats.input),
        H.utils_format_k(stats.output),
        stats.cost
      )
    )
  end

  vim.api.nvim_set_option_value('winbar', table.concat(parts), { win = llm_win })
end

--- Render the winbar (debounced to avoid rapid updates).
---@return nil
H.ui_render_winbar = function()
  -- Cancel pending debounce timer
  if H.state.ui.winbar_debounce_timer then
    H.state.ui.winbar_debounce_timer:stop()
    H.state.ui.winbar_debounce_timer:close()
    H.state.ui.winbar_debounce_timer = nil
  end

  -- During loading animation, render immediately (already throttled by animation timer)
  if H.state.loading.active then
    H.ui_render_winbar_impl()
    return
  end

  -- Debounce non-animation updates
  H.state.ui.winbar_debounce_timer = vim.loop.new_timer()
  H.state.ui.winbar_debounce_timer:start(
    H.WINBAR_DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      H.state.ui.winbar_debounce_timer = nil
      H.ui_render_winbar_impl()
    end)
  )
end

--- Create and configure a window for the LLM buffer.
---@return integer win_id  Window handle.
H.ui_create_llm_win = function()
  local window_type = Sllm.config.window_type
  local buf = H.ui_ensure_llm_buffer()

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

  H.ui_render_winbar_impl() -- Immediate render for new window
  return win_id
end

-- Loading indicator state machine =============================================

--- Start the loading animation.
---@return nil
H.ui_start_loading_indicator = function()
  if H.state.loading.active then return end

  H.state.loading.active = true
  H.state.loading.frame_idx = 1

  if H.state.loading.timer then H.state.loading.timer:close() end
  H.state.loading.timer = vim.loop.new_timer()
  H.state.loading.timer:start(
    0,
    150,
    vim.schedule_wrap(function()
      if not H.state.loading.active then
        H.state.loading.timer:stop()
        H.state.loading.timer:close()
        H.state.loading.timer = nil
        return
      end
      H.state.loading.frame_idx = (H.state.loading.frame_idx % #H.ANIMATION_FRAMES) + 1
      H.ui_render_winbar_impl() -- Direct render during animation
    end)
  )
end

--- Stop the loading animation.
---@return nil
H.ui_stop_loading_indicator = function()
  if not H.state.loading.active then return end
  H.state.loading.active = false
  if H.state.loading.timer then
    H.state.loading.timer:stop()
    H.state.loading.timer:close()
    H.state.loading.timer = nil
  end
  H.ui_render_winbar()
end

--- Clear the LLM buffer and stop any active loading animation.
---@return nil
H.ui_clean_llm_buffer = function()
  if H.state.loading.active then H.ui_stop_loading_indicator() end
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

--- Copy a code block from the LLM buffer to the clipboard.
---@param position "first"|"last"  Which code block to copy.
---@return boolean  `true` if a code block was found and copied; `false` otherwise.
H.ui_copy_code_block = function(position)
  local buf = H.ui_ensure_llm_buffer()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local code_blocks = H.utils_extract_code_blocks(lines)

  if #code_blocks == 0 then return false end

  local block = position == 'first' and code_blocks[1] or code_blocks[#code_blocks]
  vim.fn.setreg('+', block)
  vim.fn.setreg('"', block)
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

  -- Register keymaps from H.KEYMAP_DEFS constant
  local km = Sllm.config.keymaps
  if km then
    for name, def in pairs(H.KEYMAP_DEFS) do
      local key = km[name]
      if type(key) == 'string' and key ~= '' then
        vim.keymap.set(def.modes, key, Sllm[def.func_name], { desc = def.desc })
      end
    end
  end

  -- Set up backend config
  H.state.backend_config = { cmd = Sllm.config.llm_cmd }

  H.state.continue = not Sllm.config.on_start_new_chat
  H.state.selected_model = Sllm.config.default_model ~= 'default' and Sllm.config.default_model
    or H.backend.get_default_model(H.state.backend_config)
  H.state.online_enabled = Sllm.config.online_enabled or false

  H.notify = Sllm.config.notify_func
  H.pick = Sllm.config.pick_func
  H.input = Sllm.config.input_func

  -- Install default templates and set default mode
  H.install_default_templates()
  H.state.selected_template = Sllm.config.default_mode or nil
end

--- Install default templates by symlinking from plugin directory to llm templates dir.
---@return nil
H.install_default_templates = function()
  -- Get llm templates path
  local templates_path = H.backend.get_templates_path(H.state.backend_config)
  if not templates_path then
    -- Silently skip if llm templates path not available
    return
  end

  -- Get plugin templates path (absolute)
  local plugin_path = debug.getinfo(1, 'S').source:sub(2):match('(.*/)')
  if not plugin_path then return end

  -- Go up from lua/sllm/ to plugin root, then to templates/
  local plugin_templates_path = plugin_path:gsub('lua/sllm/$', '') .. 'templates'
  -- Ensure absolute path
  plugin_templates_path = vim.fn.fnamemodify(plugin_templates_path, ':p'):gsub('/$', '')

  -- Check if plugin templates directory exists
  if vim.fn.isdirectory(plugin_templates_path) == 0 then return end

  -- Get list of template files (returns absolute paths)
  local template_files = vim.fn.glob(plugin_templates_path .. '/sllm_*.yaml', false, true)

  for _, src_file in ipairs(template_files) do
    -- Ensure src_file is absolute
    src_file = vim.fn.fnamemodify(src_file, ':p')
    local filename = vim.fn.fnamemodify(src_file, ':t')
    local dst_file = templates_path .. '/' .. filename

    -- Only create symlink if destination doesn't exist or is already a symlink to our file
    if vim.fn.filereadable(dst_file) == 0 then
      -- Create symlink with absolute path
      vim.fn.system({ 'ln', '-s', src_file, dst_file })
      if vim.v.shell_error == 0 then H.notify('[sllm] installed template: ' .. filename, vim.log.levels.INFO) end
    elseif vim.fn.getftype(dst_file) == 'link' then
      -- It's a symlink, check if it points to our file
      local target = vim.fn.resolve(dst_file)
      if target ~= src_file then
        -- Different target, remove and recreate
        vim.fn.delete(dst_file)
        vim.fn.system({ 'ln', '-s', src_file, dst_file })
      end
    end
    -- If it's a regular file, leave it alone (user customized it)
  end
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

    -- Handle slash commands
    if user_input == '/' then
      -- Just "/" shows the command picker
      Sllm.run_command()
      return
    elseif user_input:match('^/') then
      -- "/cmd" executes the command directly
      local cmd = user_input:match('^/(%S+)')
      if cmd then
        Sllm.run_command(cmd)
        return
      end
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
      show_usage = Sllm.config.ui.show_usage,
      model = H.state.selected_model,
      ctx_files = ctx.fragments,
      tools = ctx.tools,
      functions = ctx.functions,
      chain_limit = Sllm.config.chain_limit,
      template = H.state.selected_template,
      online = H.state.online_enabled,
      system_prompt = H.state.system_prompt,
      model_options = H.state.model_options,
    })

    -- Debug: show command in LLM buffer
    if Sllm.config.debug then
      H.ui_append_to_llm_buffer({ '', '> 🐛 Debug: LLM command', '```bash' })
      H.ui_append_to_llm_buffer(vim.split(cmd, '\n', { plain = true }))
      H.ui_append_to_llm_buffer({ '```', '' })
    end

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
      -- stderr handler: parse token usage, show tool call headers, filter tool output
      ---@param line string
      function(line)
        -- Parse token usage and accumulate stats
        local usage = H.backend.parse_token_usage(line)
        if usage then
          H.state.session_stats.input = H.state.session_stats.input + usage.input
          H.state.session_stats.output = H.state.session_stats.output + usage.output
          H.state.session_stats.cost = H.state.session_stats.cost + usage.cost
          if Sllm.config.ui.show_usage then H.ui_render_winbar() end
          return
        end

        -- Show Tool call headers
        if H.backend.is_tool_call_header(line) then
          H.ui_append_to_llm_buffer({ line })
          return
        end

        -- Filter out tool call outputs (indented lines following Tool call headers)
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
      H.ui_render_winbar()
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
    local url = user_input and vim.trim(user_input) or nil
    if not url or url == '' then
      H.notify('[sllm] no URL provided.', vim.log.levels.INFO)
      return
    end
    H.context_add_fragment(url)
    H.notify('[sllm] URL added to context: ' .. url, vim.log.levels.INFO)
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
    local cmd = cmd_raw and vim.trim(cmd_raw) or nil
    if not cmd or cmd == '' then
      H.notify('[sllm] command canceled.', vim.log.levels.INFO)
      return
    end
    H.notify('[sllm] running command: ' .. cmd, vim.log.levels.INFO)
    local res_out = H.job_exec_cmd_capture_output(cmd)
    H.context_add_snip(res_out, 'Command-> ' .. cmd, 'text')
    H.notify('[sllm] added command output to context.', vim.log.levels.INFO)
  end)
end

--- Reset the LLM context (fragments, snippets, tools, functions).
---@return nil
function Sllm.reset_context()
  H.context_reset()
  H.notify('[sllm] context reset.', vim.log.levels.INFO)
end

--- Smart context add: file (normal mode) or selection (visual mode).
---@return nil
function Sllm.add_context()
  if H.utils_is_mode_visual() then
    Sllm.add_sel_to_ctx()
  else
    Sllm.add_file_to_ctx()
  end
end

--- Unified command picker. Shows all available commands grouped by category.
--- Also handles slash commands when called with a command string.
---@param cmd_input string? Optional command to execute directly (e.g., "new", "model").
---@return nil
function Sllm.run_command(cmd_input)
  -- If a command is provided directly, execute it
  if cmd_input and cmd_input ~= '' then
    for _, cmd_def in ipairs(H.COMMANDS) do
      if cmd_def.cmd == cmd_input then
        local action = cmd_def.action
        if type(action) == 'string' then
          Sllm[action]()
        else
          action()
        end
        return
      end
    end
    H.notify('[sllm] unknown command: ' .. cmd_input, vim.log.levels.WARN)
    return
  end

  -- Build picker items from command registry
  local items = {}
  for _, cmd_def in ipairs(H.COMMANDS) do
    table.insert(items, {
      label = string.format('[%s] /%s - %s', cmd_def.category, cmd_def.cmd, cmd_def.desc),
      cmd_def = cmd_def,
    })
  end

  local labels = vim.tbl_map(function(item) return item.label end, items)

  H.pick(labels, { prompt = 'Command:' }, function(_, idx)
    if idx then
      local cmd_def = items[idx].cmd_def
      local action = cmd_def.action
      if type(action) == 'string' then
        Sllm[action]()
      else
        action()
      end
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

--- Set or update the system prompt.
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

--- Toggle the online feature.
---@return nil
function Sllm.toggle_online()
  H.state.online_enabled = not H.state.online_enabled

  if H.state.online_enabled then
    H.notify('[sllm] 🌐 Online mode enabled', vim.log.levels.INFO)
  else
    H.notify('[sllm] 📴 Online mode disabled', vim.log.levels.INFO)
  end

  -- Update the UI title to reflect the change
  H.ui_render_winbar()
end

--- Get online status for UI display.
---@return boolean
function Sllm.is_online_enabled() return H.state.online_enabled end

--- Copy the first code block from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_first_code_block()
  if H.ui_copy_code_block('first') then
    H.notify('[sllm] first code block copied to clipboard.', vim.log.levels.INFO)
  else
    H.notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last code block from the LLM buffer to the clipboard.
---@return nil
function Sllm.copy_last_code_block()
  if H.ui_copy_code_block('last') then
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

  -- Build the completion prompt with cursor marker (template provides instructions)
  local prompt = before_text .. '<CURSOR>'
  if #after_text > 0 then prompt = prompt .. '\n' .. after_text end

  -- Build LLM command using sllm_complete template
  local llm_cmd = H.state.backend_config.cmd or 'llm'
  local cmd = llm_cmd .. ' --no-stream -t sllm_complete'
  if H.state.selected_model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(H.state.selected_model) end
  cmd = cmd .. ' ' .. vim.fn.shellescape(prompt)

  -- Debug: show command in LLM buffer
  if Sllm.config.debug then
    H.ui_show_llm_buffer()
    H.ui_append_to_llm_buffer({ '', '> 🐛 Debug: LLM command', '```bash' })
    H.ui_append_to_llm_buffer(vim.split(cmd, '\n', { plain = true }))
    H.ui_append_to_llm_buffer({ '```', '' })
  end

  -- Start loading indicator (shows in winbar if LLM buffer is visible)
  H.ui_start_loading_indicator()
  H.notify('[sllm] completing...', vim.log.levels.INFO)

  -- Collect the completion output
  local completion_output = {}

  H.job_start(
    cmd,
    function(line) -- stdout handler
      if line ~= '' then table.insert(completion_output, line) end
    end,
    function() end, -- stderr handler (ignored for completion)
    function(exit_code) -- exit handler
      H.ui_stop_loading_indicator()
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
    end
  )
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
      H.ui_render_winbar()
      H.notify('[sllm] template selected: ' .. item, vim.log.levels.INFO)
    else
      H.notify('[sllm] template not changed', vim.log.levels.WARN)
    end
  end)
end

--- Select a mode (template) to configure the session.
--- Modes are llm templates. Use `llm templates edit <name>` to customize.
---@return nil
function Sllm.select_mode() Sllm.select_template() end

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

return Sllm
