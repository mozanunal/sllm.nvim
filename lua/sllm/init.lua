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
  reset_context_after_each_prompt = true,
  pick_func = require('mini.pick').ui_select, -- vim.notify
  notify_func = require('mini.notify').make_notify(), -- vim.ui.select
  keymaps = {
    ask_llm = '<leader>ss',
    new_chat = '<leader>sn',
    cancel = '<leader>sc',
    focus_llm_buffer = '<leader>sf',
    toggle_llm_buffer = '<leader>st',
    select_model = '<leader>sm',
    add_file_to_ctx = '<leader>sa',
    add_sel_to_ctx = '<leader>sv',
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
  local cmd = Backend.llm_cmd(prompt, state.continue, config.show_usage, state.selected_model, ctx.files)

  notify('[sllm] thinking...🤔', vim.log.levels.INFO)
  state.continue = true
  JobMan.start(cmd, function(line) Ui.append_to_llm_buffer({ line }) end, function(exit_code)
    notify('[sllm] done ✅ exit code: ' .. exit_code, vim.log.levels.INFO)
    Ui.append_to_llm_buffer({ '' })
    CtxMan.reset()
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
    CtxMan.add_file(buf_path)
    notify('[sllm] context + ' .. buf_path, vim.log.levels.INFO)
  else
    notify('[sllm] buffer does not have a path: ', vim.log.levels.WARN)
  end
end

M.add_sel_to_ctx = function()
  -- Get start/end of last visual selection
  local pos1 = vim.fn.getpos("'<") -- {bufnum, lnum, col, off}
  local pos2 = vim.fn.getpos("'>")
  local start_line, start_col = pos1[2], pos1[3]
  local end_line, end_col = pos2[2], pos2[3]

  -- If no valid selection
  if start_line == 0 or end_line == 0 then
    notify('[sllm] No selection: Make a visual selection first.', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = {}

  if start_line == end_line then
    -- Single-line selection
    local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, true)[1]
    lines[1] = line:sub(start_col, end_col)
  else
    -- First line: from start_col to end
    local first = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, true)[1]
    lines[#lines + 1] = first:sub(start_col)

    -- Middle lines: full
    local middle = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line - 1, true)
    vim.list_extend(lines, middle)

    -- Last line: from 1 to end_col
    local last = vim.api.nvim_buf_get_lines(bufnr, end_line - 1, end_line, true)[1]
    lines[#lines + 1] = last:sub(1, end_col)
  end

  local text = table.concat(lines, '\n')
  if text:match('^%s*$') then
    notify('[sllm] Empty selection.', vim.log.levels.WARN)
    return
  end

  CtxMan.add_snip(text, Utils.get_relpath(Utils.get_path_of_buffer(0)), vim.bo.filetype)
  notify('[sllm] Added selection to context.', vim.log.levels.INFO)
end

M.reset_context = function()
  CtxMan.reset()
  notify('[sllm] context reset.', vim.log.levels.INFO)
end

return M
