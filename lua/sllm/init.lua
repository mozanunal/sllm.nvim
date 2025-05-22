local M = {}

local Utils = require('sllm.utils')
local Backend = require('sllm.backend.llm')
local CtxMan = require('sllm.context_manager')
local JobMan = require('sllm.job_manager')
local Ui = require('sllm.ui')

local config = {
  default_model = 'gpt-4.1',
  show_usage = true,
  on_start_new_chat = true,
  reset_ctx_each_prompt = true,
  pick_func = (pcall(require, 'mini.pick') and require('mini.pick').ui_select) or vim.ui.select,
  notify_func = (pcall(require, 'mini.notify') and require('mini.notify').make_notify()) or vim.notify,
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
    reset_context = '<leader>sr',
  },
}

local state = {
  llm_job_id = nil,
  continue = nil,
  selected_model = nil,
}

local notify = vim.notify
local pick = vim.ui.select

M.setup = function(user_config)
  config = vim.tbl_deep_extend('force', {}, config, user_config or {})

  -- set keymaps
  local km = config.keymaps -- local shorter alias to avoid repetition
  vim.keymap.set({ 'n', 'v' }, km.ask_llm, M.ask_llm, { desc = 'Ask LLM' })
  vim.keymap.set({ 'n', 'v' }, km.new_chat, M.new_chat, { desc = 'New LLM chat' })
  vim.keymap.set({ 'n', 'v' }, km.cancel, M.cancel, { desc = 'Cancel LLM request' })
  vim.keymap.set({ 'n', 'v' }, km.focus_llm_buffer, M.focus_llm_buffer, { desc = 'Focus LLM buffer' })
  vim.keymap.set({ 'n', 'v' }, km.toggle_llm_buffer, M.toggle_llm_buffer, { desc = 'Toggle LLM buffer' })
  vim.keymap.set({ 'n', 'v' }, km.select_model, M.select_model, { desc = 'Select LLM model' })
  vim.keymap.set({ 'n', 'v' }, km.add_file_to_ctx, M.add_file_to_ctx, { desc = 'Add file to llm context' })
  vim.keymap.set({ 'n', 'v' }, km.add_url_to_ctx, M.add_url_to_ctx, { desc = 'Add URL to LLM context' })
  vim.keymap.set({ 'n', 'v' }, km.add_diag_to_ctx, M.add_diag_to_ctx, { desc = 'Add diagnostics to context' })
  vim.keymap.set({ 'n', 'v' }, km.add_cmd_out_to_ctx, M.add_cmd_out_to_ctx, { desc = 'Add command output to context' })
  vim.keymap.set({ 'n', 'v' }, km.reset_context, M.reset_context, { desc = 'Reset LLM context' })
  vim.keymap.set('v', km.add_sel_to_ctx, M.add_sel_to_ctx, { desc = 'Add visual selection to context' })

  -- set state
  if config.on_start_new_chat then
    state.continue = false
  else
    state.continue = true
  end
  state.selected_model = config.default_model

  -- set functions
  notify = config.notify_func
  pick = config.pick_func
end

M.ask_llm = function()
  local user_input = vim.fn.input('Prompt: ')
  if user_input == '' then
    notify('[sllm] no prompt provided.', vim.log.levels.INFO)
    return
  end
  Ui.show_llm_buffer()

  -- Prevent multiple LLM jobs running at once:
  if JobMan.is_busy() then
    notify('[sllm] already running, please wait.', vim.log.levels.WARN)
    return
  end

  -- Get context
  local ctx = CtxMan.get()
  -- {filepath="a.lua", filetype="lua", text="require something \nsomething.call()"}
  local prompt = CtxMan.render_prompt_ui(user_input)

  local lines = vim.split(prompt, '\n', { plain = true })
  Ui.append_to_llm_buffer({ '', '> 💬 Prompt:', '' })
  Ui.append_to_llm_buffer(lines)
  Ui.append_to_llm_buffer({ '', '> 🤖 Response', '' })

  -- Run Prompt
  local cmd = Backend.llm_cmd(prompt, state.continue, config.show_usage, state.selected_model, ctx.fragments)

  notify('[sllm] thinking...🤔', vim.log.levels.INFO)
  state.continue = true
  JobMan.start(cmd, function(line) Ui.append_to_llm_buffer({ line }) end, function(exit_code)
    notify('[sllm] done ✅ exit code: ' .. exit_code, vim.log.levels.INFO)
    Ui.append_to_llm_buffer({ '' })
    if config.reset_ctx_each_prompt then CtxMan.reset() end
  end)
end

M.cancel = function()
  if JobMan.is_busy() then
    JobMan.stop()
    notify('[sllm] canceled ❌', vim.log.levels.WARN)
  else
    notify('[sllm] no active llm job', vim.log.levels.INFO)
  end
end

M.new_chat = function()
  state.continue = false
  Ui.show_llm_buffer()
  Ui.clean_llm_buffer()
  notify('[sllm] new chat created', vim.log.levels.INFO)
end

M.focus_llm_buffer = function() Ui.focus_llm_buffer() end

M.toggle_llm_buffer = function() Ui.toggle_llm_buffer() end

M.select_model = function()
  local models = Backend.extract_models()
  if not (models and #models > 0) then
    notify('[sllm] no models found.', vim.log.levels.ERROR)
    return
  end

  pick(models, {}, function(item)
    if item then
      state.selected_model = item
      notify('[sllm] selected model: ' .. item, vim.log.levels.INFO)
    else
      notify('[sllm] llm model not changed', vim.log.levels.WARN)
    end
  end)
end

M.add_file_to_ctx = function()
  local buf_path = Utils.get_relpath(Utils.get_path_of_buffer(0))
  if buf_path then
    CtxMan.add_fragment(buf_path)
    notify('[sllm] context +' .. buf_path, vim.log.levels.INFO)
  else
    notify('[sllm] buffer does not have a path: ', vim.log.levels.WARN)
  end
end

M.add_url_to_ctx = function()
  local user_input = vim.fn.input('URL: ')
  if user_input == '' then
    notify('[sllm] no URL provided.', vim.log.levels.INFO)
    return
  end
  CtxMan.add_fragment(user_input)
  notify('[sllm] URL added to context: ' .. user_input, vim.log.levels.INFO)
end

M.add_sel_to_ctx = function()
  local text = Utils.get_visual_selection()
  if text == '' or text:match('^%s*$') then
    notify('[sllm] empty selection.', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local file_path_for_snip = Utils.get_relpath(Utils.get_path_of_buffer(bufnr))
  local file_type_for_snip = vim.bo[bufnr].filetype
  CtxMan.add_snip(text, file_path_for_snip, file_type_for_snip)
  notify('[sllm] added selection to context.', vim.log.levels.INFO)
end

M.add_diag_to_ctx = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(bufnr)
  if not diagnostics or #diagnostics == 0 then
    notify('[sllm] no diagnostics found in this buffer.', vim.log.levels.INFO)
    return
  end

  -- Format diagnostics
  local formatted = {}
  for _, d in ipairs(diagnostics) do
    local msg = d.message:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
    local lnum = d.lnum and (d.lnum + 1) or '?'
    local col = d.col and (d.col + 1) or '?'
    table.insert(formatted, ('[L%d,C%d] %s'):format(lnum, col, msg))
  end
  local text = 'diagnostics:\n' .. table.concat(formatted, '\n')
  CtxMan.add_snip(text, Utils.get_relpath(Utils.get_path_of_buffer(bufnr)), vim.bo.filetype)
  notify('[sllm] Added diagnostics to context.', vim.log.levels.INFO)
end

-- New function to add command output to context
M.add_cmd_out_to_ctx = function()
  local cmd_input_raw = vim.fn.input('Command: ')
  if cmd_input_raw == '' then
    notify('[sllm] no command provided.', vim.log.levels.INFO)
    return
  end

  -- Expand Vim special characters like % (current file), # (alternate file), etc.
  local cmd_to_run = vim.fn.expandcmd(cmd_input_raw)

  if cmd_to_run == '' then
    notify('[sllm] expanded command is empty.', vim.log.levels.WARN)
    return
  end

  notify('[sllm] running command: ' .. cmd_to_run, vim.log.levels.INFO)

  vim.system({ "bash", "-c", cmd_to_run }, { text = true }, function(job_result)
    if job_result.code ~= 0 then
      local error_msg = '[sllm] command failed with exit code ' .. job_result.code
      if job_result.stderr and job_result.stderr ~= '' then
        error_msg = error_msg .. '\nStderr:\n' .. vim.trim(job_result.stderr)
      end
      notify(error_msg, vim.log.levels.ERROR)
      return
    end

    local output_stdout = vim.trim(job_result.stdout or "")
    local output_stderr = vim.trim(job_result.stderr or "")
    local combined_output = output_stdout

    if output_stderr ~= '' then
      if combined_output ~= '' then
        combined_output = combined_output .. "\n--- stderr ---\n" .. output_stderr
      else
        combined_output = "--- stderr ---\n" .. output_stderr
      end
    end

    if combined_output == '' then
      notify('[sllm] command produced no output.', vim.log.levels.WARN)
      return
    end

    -- Use the raw command input for the snip "filepath" for user clarity
    CtxMan.add_snip(combined_output, 'Command: ' .. cmd_input_raw, 'text')
    notify('[sllm] added command output to context.', vim.log.levels.INFO)
  end)
end

M.reset_context = function()
  CtxMan.reset()
  notify('[sllm] context reset.', vim.log.levels.INFO)
end

return M
