---@module "sllm"

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
local M = {}

local Utils = require('sllm.utils')
local Backend = require('sllm.backend.llm')
local CtxMan = require('sllm.context_manager')
local JobMan = require('sllm.job_manager')
local Ui = require('sllm.ui')

--- Module configuration (with defaults).
---@type SllmConfig
local config = {
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
  },
}

--- Internal state.
local state = {
  continue = nil,
  selected_model = nil,
  system_prompt = nil,
  model_options = {},
  online_enabled = false,
}

---@type fun(msg: string, level?: number)
local notify = vim.notify

---@type fun(items: any[], opts: table?, on_choice: fun(item: any, idx?: integer))
local pick = vim.ui.select

---@type fun(opts: table, on_confirm: fun(input: string?))
local input = vim.ui.input

--- Setup sllm.nvim with optional overrides.
---
---@param user_config SllmConfig?  Partial overrides for defaults.
---@return nil
function M.setup(user_config)
  config = vim.tbl_deep_extend('force', {}, config, user_config or {})

  local km = config.keymaps
  if km then
    local keymap_defs = {
      ask_llm = { modes = { 'n', 'v' }, func = M.ask_llm, desc = 'Ask LLM' },
      new_chat = { modes = { 'n', 'v' }, func = M.new_chat, desc = 'New LLM chat' },
      cancel = { modes = { 'n', 'v' }, func = M.cancel, desc = 'Cancel LLM request' },
      focus_llm_buffer = { modes = { 'n', 'v' }, func = M.focus_llm_buffer, desc = 'Focus LLM buffer' },
      toggle_llm_buffer = { modes = { 'n', 'v' }, func = M.toggle_llm_buffer, desc = 'Toggle LLM buffer' },
      select_model = { modes = { 'n', 'v' }, func = M.select_model, desc = 'Select LLM model' },
      add_tool_to_ctx = { modes = { 'n', 'v' }, func = M.add_tool_to_ctx, desc = 'Add tool to context' },
      add_file_to_ctx = { modes = { 'n', 'v' }, func = M.add_file_to_ctx, desc = 'Add file to context' },
      add_url_to_ctx = { modes = { 'n', 'v' }, func = M.add_url_to_ctx, desc = 'Add URL to context' },
      add_diag_to_ctx = { modes = { 'n', 'v' }, func = M.add_diag_to_ctx, desc = 'Add diagnostics to context' },
      add_cmd_out_to_ctx = { modes = { 'n', 'v' }, func = M.add_cmd_out_to_ctx, desc = 'Add command output to context' },
      reset_context = { modes = { 'n', 'v' }, func = M.reset_context, desc = 'Reset LLM context' },
      add_sel_to_ctx = { modes = 'v', func = M.add_sel_to_ctx, desc = 'Add visual selection to context' },
      add_func_to_ctx = { modes = 'n', func = M.add_func_to_ctx, desc = 'Add selected function to context' },
      set_system_prompt = { modes = { 'n', 'v' }, func = M.set_system_prompt, desc = 'Set system prompt' },
      set_model_option = { modes = { 'n', 'v' }, func = M.set_model_option, desc = 'Set model option' },
      show_model_options = { modes = { 'n', 'v' }, func = M.show_model_options, desc = 'Show available model options' },
      toggle_online = { modes = { 'n', 'v' }, func = M.toggle_online, desc = 'Toggle online mode' },
      copy_first_code_block = { modes = { 'n', 'v' }, func = M.copy_first_code_block, desc = 'Copy first code block' },
      copy_last_code_block = { modes = { 'n', 'v' }, func = M.copy_last_code_block, desc = 'Copy last code block' },
      copy_last_response = { modes = { 'n', 'v' }, func = M.copy_last_response, desc = 'Copy last response' },
      complete_code = { modes = { 'n', 'i' }, func = M.complete_code, desc = 'Complete code at cursor' },
    }

    for name, def in pairs(keymap_defs) do
      local key = km[name]
      if type(key) == 'string' and key ~= '' then vim.keymap.set(def.modes, key, def.func, { desc = def.desc }) end
    end
  end

  state.continue = not config.on_start_new_chat
  state.selected_model = config.default_model ~= 'default' and config.default_model
    or Backend.get_default_model(config.llm_cmd)
  state.system_prompt = config.system_prompt
  state.model_options = config.model_options or {}
  state.online_enabled = config.online_enabled or false

  -- Set online option if enabled by default
  if state.online_enabled then state.model_options.online = 1 end

  notify = config.notify_func
  pick = config.pick_func
  input = config.input_func
end

--- Ask the LLM with a prompt from the user.
---@return nil
function M.ask_llm()
  if Utils.is_mode_visual() then M.add_sel_to_ctx() end
  input({ prompt = 'Prompt: ' }, function(user_input)
    if user_input == '' then
      notify('[sllm] no prompt provided.', vim.log.levels.INFO)
      return
    end
    if user_input == nil then
      notify('[sllm] prompt canceled.', vim.log.levels.INFO)
      return
    end

    Ui.show_llm_buffer(config.window_type, state.selected_model, state.online_enabled)
    if JobMan.is_busy() then
      notify('[sllm] already running, please wait.', vim.log.levels.WARN)
      return
    end

    if config.pre_hooks then
      for _, hook in ipairs(config.pre_hooks) do
        local output = JobMan.exec_cmd_capture_output(hook.command)
        if hook.add_to_context then
          CtxMan.add_snip(output, 'Pre-hook-> ' .. hook.command, 'text')
          notify('[sllm] pre-hook executed, added to context ' .. hook.command, vim.log.levels.INFO)
        end
      end
    end

    local ctx = CtxMan.get()
    local prompt = CtxMan.render_prompt_ui(user_input)
    Ui.append_to_llm_buffer({ '', '> 💬 Prompt:', '' }, config.scroll_to_bottom)
    Ui.append_to_llm_buffer(vim.split(prompt, '\n', { plain = true }), config.scroll_to_bottom)
    Ui.start_loading_indicator()

    local cmd = Backend.llm_cmd(
      config.llm_cmd,
      prompt,
      state.continue,
      config.show_usage,
      state.selected_model,
      ctx.fragments,
      ctx.tools,
      ctx.functions,
      state.system_prompt,
      state.model_options
    )
    state.continue = true

    local first_line = false
    JobMan.start(
      cmd,
      ---@param line string
      function(line)
        if not first_line then
          Ui.stop_loading_indicator()
          Ui.append_to_llm_buffer({ '', '> 🤖 Response', '' }, config.scroll_to_bottom)
          first_line = true
        end
        Ui.append_to_llm_buffer({ line }, config.scroll_to_bottom)
      end,
      ---@param exit_code integer
      function(exit_code)
        Ui.stop_loading_indicator()
        if not first_line then
          Ui.append_to_llm_buffer({ '', '> 🤖 Response', '' }, config.scroll_to_bottom)
          local msg = exit_code == 0 and '(empty response)' or string.format('(failed or canceled: exit %d)', exit_code)
          Ui.append_to_llm_buffer({ msg }, config.scroll_to_bottom)
        end
        notify('[sllm] done ✅ exit code: ' .. exit_code, vim.log.levels.INFO)
        Ui.append_to_llm_buffer({ '' }, config.scroll_to_bottom)
        if config.reset_ctx_each_prompt then CtxMan.reset() end
        if config.post_hooks then
          for _, hook in ipairs(config.post_hooks) do
            local _ = JobMan.exec_cmd_capture_output(hook.command)
          end
        end
      end
    )
  end)
end

--- Cancel the in-flight LLM request, if any.
---@return nil
function M.cancel()
  if JobMan.is_busy() then
    JobMan.stop()
    notify('[sllm] canceling request...', vim.log.levels.WARN)
  else
    notify('[sllm] no active llm job', vim.log.levels.INFO)
  end
end

--- Start a new chat (clears buffer and state).
---@return nil
function M.new_chat()
  if JobMan.is_busy() then
    JobMan.stop()
    notify('[sllm] previous request canceled for new chat.', vim.log.levels.INFO)
  end
  state.continue = false
  Ui.show_llm_buffer(config.window_type, state.selected_model, state.online_enabled)
  Ui.clean_llm_buffer()
  notify('[sllm] new chat created', vim.log.levels.INFO)
end

--- Focus the existing LLM window or create it.
---@return nil
function M.focus_llm_buffer() Ui.focus_llm_buffer(config.window_type, state.selected_model, state.online_enabled) end

--- Toggle visibility of the LLM window.
---@return nil
function M.toggle_llm_buffer() Ui.toggle_llm_buffer(config.window_type, state.selected_model, state.online_enabled) end

--- Prompt user to select an LLM model.
---@return nil
function M.select_model()
  local models = Backend.extract_models(config.llm_cmd)
  if not (models and #models > 0) then
    notify('[sllm] no models found.', vim.log.levels.ERROR)
    return
  end
  pick(models, {}, function(item)
    if item then
      state.selected_model = item
      notify('[sllm] selected model: ' .. item, vim.log.levels.INFO)
      Ui.update_llm_win_title(state.selected_model, state.online_enabled)
    else
      notify('[sllm] llm model not changed', vim.log.levels.WARN)
    end
  end)
end

--- Add a tool to the current context.
---@return nil
function M.add_tool_to_ctx()
  local tools = Backend.extract_tools(config.llm_cmd)
  if not (tools and #tools > 0) then
    notify('[sllm] no tools found.', vim.log.levels.ERROR)
    return
  end
  pick(tools, {}, function(item)
    if item then
      CtxMan.add_tool(item)
      notify('[sllm] tool added: ' .. item, vim.log.levels.INFO)
    else
      notify('[sllm] no tools added.', vim.log.levels.WARN)
    end
  end)
end

--- Add the current file (or URL) path to the context.
---@return nil
function M.add_file_to_ctx()
  local buf_path = Utils.get_path_of_buffer(0)
  if buf_path then
    CtxMan.add_fragment(buf_path)
    notify('[sllm] context +' .. Utils.get_relpath(buf_path), vim.log.levels.INFO)
  else
    notify('[sllm] buffer does not have a path.', vim.log.levels.WARN)
  end
end

--- Prompt user for a URL and add it to context.
---@return nil
function M.add_url_to_ctx()
  input({ prompt = 'URL: ' }, function(user_input)
    if user_input == '' then
      notify('[sllm] no URL provided.', vim.log.levels.INFO)
      return
    end
    CtxMan.add_fragment(user_input)
    notify('[sllm] URL added to context: ' .. user_input, vim.log.levels.INFO)
  end)
end

--- Add the current function or entire buffer to context.
---@return nil
function M.add_func_to_ctx()
  local text
  if Utils.is_mode_visual() then
    text = Utils.get_visual_selection()
    if text:match('^%s*$') then
      notify('[sllm] empty selection.', vim.log.levels.WARN)
      return
    end
  else
    local bufnr = vim.api.nvim_get_current_buf()
    text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    if text:match('^%s*$') then
      notify('[sllm] file is empty.', vim.log.levels.WARN)
      return
    end
  end
  CtxMan.add_function(text)
  notify('[sllm] added function to context.', vim.log.levels.INFO)
end

--- Add the current visual selection as a code snippet.
---@return nil
function M.add_sel_to_ctx()
  local text = Utils.get_visual_selection()
  if text:match('^%s*$') then
    notify('[sllm] empty selection.', vim.log.levels.WARN)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  CtxMan.add_snip(text, Utils.get_relpath(Utils.get_path_of_buffer(bufnr)), vim.bo[bufnr].filetype)
  notify('[sllm] added selection to context.', vim.log.levels.INFO)
end

--- Add current buffer diagnostics to context as a snippet.
---@return nil
function M.add_diag_to_ctx()
  local bufnr = vim.api.nvim_get_current_buf()
  local diags = vim.diagnostic.get(bufnr)
  if not diags or #diags == 0 then
    notify('[sllm] no diagnostics found in buffer.', vim.log.levels.INFO)
    return
  end
  local lines = {}
  for _, d in ipairs(diags) do
    local msg = d.message:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
    local loc = ('[L%d,C%d]'):format((d.lnum or 0) + 1, (d.col or 0) + 1)
    table.insert(lines, loc .. ' ' .. msg)
  end
  CtxMan.add_snip(
    'diagnostics:\n' .. table.concat(lines, '\n'),
    Utils.get_relpath(Utils.get_path_of_buffer(bufnr)),
    vim.bo[bufnr].filetype
  )
  notify('[sllm] added diagnostics to context.', vim.log.levels.INFO)
end

--- Prompt for a shell command, run it, and add its output to context.
---@return nil
function M.add_cmd_out_to_ctx()
  input({ prompt = 'Command: ' }, function(cmd_raw)
    notify('[sllm] running command: ' .. cmd_raw, vim.log.levels.INFO)
    local res_out = JobMan.exec_cmd_capture_output(cmd_raw)
    CtxMan.add_snip(res_out, 'Command-> ' .. cmd_raw, 'text')
    notify('[sllm] added command output to context.', vim.log.levels.INFO)
  end)
end

--- Reset the LLM context (fragments, snippets, tools, functions).
---@return nil
function M.reset_context()
  CtxMan.reset()
  notify('[sllm] context reset.', vim.log.levels.INFO)
end

--- Set the system prompt on-the-fly.
---@return nil
function M.set_system_prompt()
  input({ prompt = 'System Prompt: ', default = state.system_prompt or '' }, function(user_input)
    if user_input == nil then
      notify('[sllm] system prompt not changed.', vim.log.levels.INFO)
      return
    end
    if user_input == '' then
      state.system_prompt = nil
      notify('[sllm] system prompt cleared.', vim.log.levels.INFO)
    else
      state.system_prompt = user_input
      notify('[sllm] system prompt updated.', vim.log.levels.INFO)
    end
  end)
end

--- Show available options for the current model.
---@return nil
function M.show_model_options()
  if not state.selected_model then
    notify('[sllm] no model selected.', vim.log.levels.WARN)
    return
  end

  -- Run `llm models --options -m <model>` to show available options
  local cmd = config.llm_cmd .. ' models --options -m ' .. vim.fn.shellescape(state.selected_model)
  local output = vim.fn.systemlist(cmd)

  -- Display in a floating window or show in the LLM buffer
  Ui.show_llm_buffer(config.window_type, state.selected_model, state.online_enabled)
  Ui.append_to_llm_buffer({ '', '> 📋 Available options for ' .. state.selected_model, '' }, config.scroll_to_bottom)
  Ui.append_to_llm_buffer(output, config.scroll_to_bottom)
  Ui.append_to_llm_buffer({ '' }, config.scroll_to_bottom)
  notify('[sllm] showing model options', vim.log.levels.INFO)
end

--- Set or update a model option.
---@return nil
function M.set_model_option()
  input({ prompt = 'Option key: ' }, function(key)
    if not key or key == '' then
      notify('[sllm] no key provided.', vim.log.levels.INFO)
      return
    end
    input({ prompt = 'Option value for "' .. key .. '": ' }, function(value)
      if not value or value == '' then
        notify('[sllm] no value provided.', vim.log.levels.INFO)
        return
      end
      -- Try to convert to number if it looks like a number
      local num_value = tonumber(value)
      state.model_options[key] = num_value or value
      notify('[sllm] set option: ' .. key .. ' = ' .. value, vim.log.levels.INFO)
    end)
  end)
end

--- Reset all model options.
---@return nil
function M.reset_model_options()
  state.model_options = {}
  notify('[sllm] model options reset.', vim.log.levels.INFO)
end

--- Toggle the online feature (adds/removes online=1 option).
---@return nil
function M.toggle_online()
  state.online_enabled = not state.online_enabled

  if state.online_enabled then
    state.model_options.online = 1
    notify('[sllm] 🌐 Online mode enabled', vim.log.levels.INFO)
  else
    state.model_options.online = nil
    notify('[sllm] 📴 Online mode disabled', vim.log.levels.INFO)
  end

  -- Update the UI title to reflect the change
  Ui.update_llm_win_title(state.selected_model, state.online_enabled)
end

--- Get online status for UI display.
---@return boolean
function M.is_online_enabled() return state.online_enabled end

--- Copy the first code block from the LLM buffer to the clipboard.
---@return nil
function M.copy_first_code_block()
  if Ui.copy_first_code_block() then
    notify('[sllm] first code block copied to clipboard.', vim.log.levels.INFO)
  else
    notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last code block from the LLM buffer to the clipboard.
---@return nil
function M.copy_last_code_block()
  if Ui.copy_last_code_block() then
    notify('[sllm] last code block copied to clipboard.', vim.log.levels.INFO)
  else
    notify('[sllm] no code blocks found in response.', vim.log.levels.WARN)
  end
end

--- Copy the last response from the LLM buffer to the clipboard.
---@return nil
function M.copy_last_response()
  if Ui.copy_last_response() then
    notify('[sllm] last response copied to clipboard.', vim.log.levels.INFO)
  else
    notify('[sllm] no response found in LLM buffer.', vim.log.levels.WARN)
  end
end

--- Complete code at cursor position.
---@return nil
function M.complete_code()
  if JobMan.is_busy() then
    notify('[sllm] already running, please wait.', vim.log.levels.WARN)
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
  local prompt =
    'Complete the code at the cursor position marked with <CURSOR>. Output ONLY the completion code, no explanations, no markdown formatting.\n\n'
  prompt = prompt .. before_text .. '<CURSOR>'
  if #after_text > 0 then prompt = prompt .. '\n' .. after_text end

  -- Build LLM command - no continuation, no usage stats for cleaner output
  local cmd = config.llm_cmd .. ' --no-stream'
  if state.selected_model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(state.selected_model) end
  cmd = cmd .. ' ' .. vim.fn.shellescape(prompt)

  notify('[sllm] requesting completion...', vim.log.levels.INFO)

  -- Collect the completion output
  local completion_output = {}

  JobMan.start(cmd, function(line)
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

        notify('[sllm] completion inserted', vim.log.levels.INFO)
      else
        notify('[sllm] received empty completion', vim.log.levels.WARN)
      end
    else
      notify('[sllm] completion failed (exit code: ' .. exit_code .. ')', vim.log.levels.ERROR)
    end
  end)
end

return M
