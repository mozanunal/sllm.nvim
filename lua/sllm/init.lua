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
  default_model = 'gpt-4.1',
  show_usage = true,
  on_start_new_chat = true,
  reset_ctx_each_prompt = true,
  window_type = 'vertical',
  scroll_to_bottom = true,
  pick_func = (pcall(require, 'mini.pick') and require('mini.pick').ui_select) or vim.ui.select,
  notify_func = (pcall(require, 'mini.notify') and require('mini.notify').make_notify()) or vim.notify,
  input_func = vim.ui.input,
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
  },
}

--- Internal state.
---@type SllmState
local state = {
  continue = nil,
  selected_model = nil,
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
    }

    for name, def in pairs(keymap_defs) do
      local key = km[name]
      if type(key) == 'string' and key ~= '' then vim.keymap.set(def.modes, key, def.func, { desc = def.desc }) end
    end
  end

  state.continue = not config.on_start_new_chat
  state.selected_model = config.default_model ~= 'default' and config.default_model or nil

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

    Ui.show_llm_buffer(config.window_type, state.selected_model)
    if JobMan.is_busy() then
      notify('[sllm] already running, please wait.', vim.log.levels.WARN)
      return
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
      ctx.functions
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
  Ui.show_llm_buffer(config.window_type, state.selected_model)
  Ui.clean_llm_buffer()
  notify('[sllm] new chat created', vim.log.levels.INFO)
end

--- Focus the existing LLM window or create it.
---@return nil
function M.focus_llm_buffer() Ui.focus_llm_buffer(config.window_type, state.selected_model) end

--- Toggle visibility of the LLM window.
---@return nil
function M.toggle_llm_buffer() Ui.toggle_llm_buffer(config.window_type, state.selected_model) end

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
      Ui.update_llm_win_title(state.selected_model)
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
    if cmd_raw == '' then
      notify('[sllm] no command provided.', vim.log.levels.INFO)
      return
    end
    local cmd_to_run = vim.fn.expandcmd(cmd_raw)
    if cmd_to_run == '' then
      notify('[sllm] expanded command is empty.', vim.log.levels.WARN)
      return
    end

    notify('[sllm] running command: ' .. cmd_to_run, vim.log.levels.INFO)
    vim.system({ 'bash', '-c', cmd_to_run }, { text = true }, function(res)
      if res.code ~= 0 then
        local err = '[sllm] command failed (exit ' .. res.code .. ')'
        if res.stderr and res.stderr ~= '' then err = err .. '\nStderr:\n' .. vim.trim(res.stderr) end
        notify(err, vim.log.levels.ERROR)
        return
      end

      local out = vim.trim(res.stdout or '')
      local errout = vim.trim(res.stderr or '')
      local combined = out
      if errout ~= '' then
        combined = (combined ~= '' and combined .. '\n--- stderr ---\n' .. errout) or ('--- stderr ---\n' .. errout)
      end
      if combined == '' then
        notify('[sllm] command produced no output.', vim.log.levels.WARN)
        return
      end

      CtxMan.add_snip(combined, 'Command: ' .. cmd_raw, 'text')
      notify('[sllm] added command output to context.', vim.log.levels.INFO)
    end)
  end)
end

--- Reset the LLM context (fragments, snippets, tools, functions).
---@return nil
function M.reset_context()
  CtxMan.reset()
  notify('[sllm] context reset.', vim.log.levels.INFO)
end

return M
