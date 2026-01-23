---@module "sllm.backend.llm"
--- LLM CLI backend for sllm.
--- Wraps Simon Willison's llm CLI tool.

-- Module definition ==========================================================
local Backend = { name = 'llm' }
local H = {}

-- Private state ==============================================================
H.state = {
  job_id = nil, -- current job ID
}

-- Configuration (set via setup_async)
H.config = {
  cmd = 'llm',
}

-- Helper data ================================================================

-- Treat these extensions as attachments (images, documents, archives, media, etc.).
-- Using a set avoids re-allocating a list and doing linear scans on every call.
H.ATTACHMENT_EXTENSIONS = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  bmp = true,
  webp = true,
  svg = true,
  ico = true,
  tiff = true,
  tif = true,
  pdf = true,
  doc = true,
  docx = true,
  xls = true,
  xlsx = true,
  ppt = true,
  pptx = true,
  mp3 = true,
  mp4 = true,
  wav = true,
  avi = true,
  mov = true,
  mkv = true,
  flac = true,
  ogg = true,
  zip = true,
  tar = true,
  gz = true,
  rar = true,
  ['7z'] = true,
}

-- Parse JSON string safely with error handling.
H.parse_json = function(json_str)
  local ok, result = pcall(vim.fn.json_decode, json_str)
  return ok and result or nil
end

-- Validate templates path result.
H.is_valid_templates_path = function(path) return path ~= '' and path:sub(1, 5) ~= 'Error' end

-- Get the templates directory path (sync).
H.get_templates_path = function()
  local result = vim.system({ H.config.cmd, 'templates', 'path' }, { text = true }):wait()
  local path = vim.trim(result.stdout or '')
  return H.is_valid_templates_path(path) and path or nil
end

-- Get the templates directory path (async).
H.get_templates_path_async = function(callback)
  vim.system({ H.config.cmd, 'templates', 'path' }, { text = true }, function(result)
    local path = vim.trim(result.stdout or '')
    vim.schedule(function() callback(H.is_valid_templates_path(path) and path or nil) end)
  end)
end

-- Check if a file should be treated as an attachment (image, PDF, etc.)
H.is_attachment = function(filename)
  local ext = filename:match('%.([^%.]+)$')
  if not ext then return false end
  return H.ATTACHMENT_EXTENSIONS[ext:lower()] or false
end

-- Remove ANSI escape codes from a string.
H.strip_ansi_codes = function(text)
  local ansi_escape_pattern = '[\27\155][][()#;?%][0-9;]*[A-Za-z@^_`{|}~]'
  return text:gsub(ansi_escape_pattern, '')
end

-- Start a new job and stream its output line by line.
-- Wraps the command in bash to prefix stdout lines with `--stdout ` and
-- stderr lines with `--stderr `, then routes them to the appropriate handlers.
H.job_start = function(cmd, on_stdout, on_stderr, on_exit)
  -- Helper to route a line to the appropriate handler based on --stdout/--stderr prefix
  local function route_line(line)
    local stripped = H.strip_ansi_codes(line):gsub('\r', '')
    local stdout_content = stripped:match('^%-%-stdout (.*)$')
    local stderr_content = stripped:match('^%-%-stderr (.*)$')

    if stdout_content then
      on_stdout(stdout_content)
    elseif stderr_content then
      on_stderr(stderr_content)
    elseif stripped == '--stdout' then
      on_stdout('')
    elseif stripped == '--stderr' then
      on_stderr('')
    else
      on_stdout(stripped)
    end
  end

  -- Build shell command that prefixes stdout with --stdout and stderr with --stderr
  local base_cmd
  if type(cmd) == 'table' then
    local escaped_parts = {}
    for _, part in ipairs(cmd) do
      table.insert(escaped_parts, vim.fn.shellescape(part))
    end
    base_cmd = table.concat(escaped_parts, ' ')
  else
    base_cmd = cmd
  end
  local shell_cmd = string.format("{ { %s | sed 's/^/--stdout /'; } 2>&1 1>&3 | sed 's/^/--stderr /'; } 3>&1", base_cmd)

  H.state.job_id = vim.fn.jobstart({ 'bash', '-c', shell_cmd }, {
    stdout_buffered = false,
    pty = true,
    on_stdout = function(_, data, _)
      if not data then return end
      for _, line in ipairs(data) do
        if line ~= '' then route_line(line) end
      end
    end,
    on_stderr = function(_, data, _)
      if not data then return end
      for _, line in ipairs(data) do
        if line ~= '' then on_stderr(H.strip_ansi_codes(line)) end
      end
    end,
    on_exit = function(_, exit_code, _)
      H.state.job_id = nil
      on_exit(exit_code)
    end,
  })
end

-- Stop the currently running job, if any.
H.job_stop = function()
  if H.state.job_id then
    vim.fn.jobstop(H.state.job_id)
    H.state.job_id = nil
  end
end

-- Build the llm CLI command (private helper).
---@param options LlmBuildCommandOptions Command options.
---@return string[] The assembled shell command.
H.build_command = function(options)
  local cmd = { H.config.cmd }
  if not options.prompt then error('prompt is required') end

  -- Helper to add flag with optional value(s)
  local function add(flag, ...)
    table.insert(cmd, flag)
    for _, v in ipairs({ ... }) do
      table.insert(cmd, tostring(v))
    end
  end

  -- Tool flags unless raw mode
  if not options.raw then
    add('--td')
    add('--cl', options.chain_limit or 100)
  end

  if options.no_stream then add('--no-stream') end

  if type(options.continue) == 'string' then
    add('--cid', options.continue)
  elseif options.continue then
    add('-c')
  end

  if options.show_usage then add('-u') end
  if options.model then add('-m', options.model) end

  if options.ctx_files then
    for _, filename in ipairs(options.ctx_files) do
      add(H.is_attachment(filename) and '-a' or '-f', filename)
    end
  end

  if options.tools then
    for _, tool_name in ipairs(options.tools) do
      add('-T', tool_name)
    end
  end

  if options.functions then
    for _, func_str in ipairs(options.functions) do
      add('--functions', func_str)
    end
  end

  if options.online then add('-o', 'online', '1') end
  if options.system_prompt then add('-s', options.system_prompt) end

  if options.model_options then
    for key, value in pairs(options.model_options) do
      add('-o', key, value)
    end
  end

  if options.template then add('-t', options.template) end

  add('--', options.prompt)
  return cmd
end

-- Public API =================================================================

---@class BackendSetupOptions
---@field cmd string? Command or path to the LLM CLI (default: "llm").
---@field plugin_templates_path string? Path to plugin templates directory.
---@field on_template_installed fun(filename: string)? Callback when a template is installed.
---@field on_ready fun(default_model: string?)? Callback when setup is complete, receives default model.

---Async setup for the LLM backend. Fetches default model and installs templates.
---@param options BackendSetupOptions? Setup options.
Backend.setup_async = function(options)
  options = options or {}

  -- Store config
  if options.cmd then H.config.cmd = options.cmd end

  local plugin_templates_path = options.plugin_templates_path
  local on_template_installed = options.on_template_installed
  local on_ready = options.on_ready

  -- Track completion of async tasks
  local default_model = nil
  local templates_done = false
  local model_done = false

  local function check_ready()
    if templates_done and model_done and on_ready then on_ready(default_model) end
  end

  -- Fetch default model asynchronously
  vim.system({ H.config.cmd, 'models', 'default' }, { text = true }, function(result)
    local output = result.stdout or ''
    default_model = output:match('(.-)%s*$')
    vim.schedule(function()
      model_done = true
      check_ready()
    end)
  end)

  -- Install templates if path provided
  if not plugin_templates_path or vim.fn.isdirectory(plugin_templates_path) == 0 then
    templates_done = true
    check_ready()
    return
  end

  local template_files = vim.fn.glob(plugin_templates_path .. '/sllm_*.yaml', false, true)
  if #template_files == 0 then
    templates_done = true
    check_ready()
    return
  end

  -- Get llm templates path asynchronously
  H.get_templates_path_async(function(templates_path)
    if not templates_path then
      templates_done = true
      check_ready()
      return
    end

    for _, src_file in ipairs(template_files) do
      src_file = vim.fn.fnamemodify(src_file, ':p')
      local filename = vim.fn.fnamemodify(src_file, ':t')
      local dst_file = templates_path .. '/' .. filename

      if vim.fn.filereadable(dst_file) == 0 then
        vim.system({ 'ln', '-s', src_file, dst_file }, { text = true }, function(ln_result)
          if ln_result.code == 0 and on_template_installed then
            vim.schedule(function() on_template_installed(filename) end)
          end
        end)
      elseif vim.fn.getftype(dst_file) == 'link' then
        local target = vim.fn.resolve(dst_file)
        if target ~= src_file then
          vim.fn.delete(dst_file)
          vim.system({ 'ln', '-s', src_file, dst_file }, { text = true })
        end
      end
    end

    templates_done = true
    check_ready()
  end)
end

---Cancel the current running job.
---@return nil
Backend.cancel = function() H.job_stop() end

---Check if a job is currently running.
---@return boolean True if a job is active.
Backend.is_busy = function() return H.state.job_id ~= nil end

---@class PromptUsage
---@field input integer Input tokens used.
---@field output integer Output tokens generated.
---@field cost number Cost in dollars.

---@class PromptCallbacks
---@field on_line fun(line: string)? Callback for each output line (response + tool calls).
---@field on_exit fun(exit_code: integer, conversation_id: string?, usage: PromptUsage?)? Callback when job exits.

---Prompt the LLM asynchronously.
---Handles token usage tracking internally and formats tool call headers.
---@param options LlmBuildCommandOptions Prompt options.
---@param callbacks PromptCallbacks Callbacks for line output and exit.
---@return nil
Backend.prompt_async = function(options, callbacks)
  callbacks = callbacks or {}
  local on_line = callbacks.on_line or function() end
  local on_exit = callbacks.on_exit or function() end

  -- Accumulated usage stats
  local usage = { input = 0, output = 0, cost = 0 }

  local cmd = H.build_command(options)

  H.job_start(
    cmd,
    -- stdout handler: pass through to on_line
    on_line,
    -- stderr handler: parse usage, format tool calls, filter tool output
    function(line)
      -- Parse token usage and accumulate stats
      local parsed_usage = Backend.parse_token_usage(line)
      if parsed_usage then
        usage.input = usage.input + parsed_usage.input
        usage.output = usage.output + parsed_usage.output
        usage.cost = usage.cost + parsed_usage.cost
        return
      end

      -- Format tool call headers as markdown
      if Backend.is_tool_call_header(line) then
        local tool_call = line:match('^Tool call:%s*(.+)$')
        if tool_call then
          if #tool_call > 60 then tool_call = tool_call:sub(1, 57) .. '...' end
          on_line('🔧 Tool: `' .. tool_call .. '`')
        else
          on_line(line)
        end
        return
      end

      -- Filter out tool call outputs (indented lines following Tool call headers)
      if Backend.is_tool_call_output(line) then return end

      -- Pass through other non-empty stderr lines
      if line ~= '' then on_line(line) end
    end,
    -- exit handler: fetch conversation ID and pass usage
    function(exit_code)
      local conversation_id = nil
      if exit_code == 0 then
        local result = vim.system({ H.config.cmd, 'logs', 'list', '--json', '-n', '1' }, { text = true }):wait()
        local output = result.stdout or ''
        local parsed = H.parse_json(output)
        if parsed and #parsed > 0 then conversation_id = parsed[1].conversation_id end
      end
      -- Only pass usage if we collected any
      local final_usage = (usage.input > 0 or usage.output > 0) and usage or nil
      on_exit(exit_code, conversation_id, final_usage)
    end
  )
end

---Get the built command for debugging purposes.
---@param options LlmBuildCommandOptions Command options.
---@return string[] The assembled shell command.
Backend.get_command = function(options) return H.build_command(options) end

---@class LlmBuildCommandOptions
---@field prompt string Required prompt text.
---@field model string? Model name.
---@field template string? Template name.
---@field continue boolean|string? Continue conversation (true for -c, string for --cid).
---@field show_usage boolean? Show token usage.
---@field no_stream boolean? Disable streaming output.
---@field raw boolean? Skip tool flags (--td --cl) for simple prompts.
---@field ctx_files string[]? Context files to include.
---@field tools string[]? Tool names to use.
---@field functions string[]? Python functions to use.
---@field online boolean? Enable online mode.
---@field system_prompt string? System prompt.
---@field model_options table? Model-specific options.
---@field chain_limit integer? Chain limit for tools (default: 100).

---Get list of available models from llm CLI (async).
---@param callback fun(models: string[]) Callback with list of model names.
---@return nil
Backend.get_models_async = function(callback)
  vim.system({ H.config.cmd, 'models' }, { text = true }, function(result)
    vim.schedule(function()
      local models = vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })
      local only_models = {}
      for _, line in ipairs(models) do
        local model = line:match('^.-:%s*([^(%s]+)')
        if model then table.insert(only_models, model) end
      end
      callback(only_models)
    end)
  end)
end

---Get model-specific options (async).
---@param model string Model name.
---@param callback fun(options: string[]) Callback with list of options description lines.
---@return nil
Backend.get_model_options_async = function(model, callback)
  vim.system({ H.config.cmd, 'models', '--options', '-m', model }, { text = true }, function(result)
    vim.schedule(function() callback(vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })) end)
  end)
end

---Get list of available tools from llm CLI (async).
---@param callback fun(tools: string[]) Callback with list of tool names.
---@return nil
Backend.get_tools_async = function(callback)
  vim.system({ H.config.cmd, 'tools', 'list', '--json' }, { text = true }, function(result)
    vim.schedule(function()
      local json_string = result.stdout or ''
      local spec = H.parse_json(json_string)
      local names = {}
      if spec and spec.tools then
        for _, tool in ipairs(spec.tools) do
          table.insert(names, tool.name)
        end
      end
      callback(names)
    end)
  end)
end

---Fetch history entries from llm logs (async).
---@param options table? History options.
---@param callback fun(entries: table[]?) Callback with list of history entries or nil.
---@return nil
Backend.get_history_async = function(options, callback)
  options = options or {}
  local count = options.count or 20
  local cmd = { H.config.cmd, 'logs', 'list', '--json', '-n', tostring(count) }

  if options.query then
    table.insert(cmd, '-q')
    table.insert(cmd, options.query)
  end
  if options.model then
    table.insert(cmd, '-m')
    table.insert(cmd, options.model)
  end

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      local output = result.stdout or ''
      local parsed = H.parse_json(output)

      if not parsed then
        callback(nil)
        return
      end

      local entries = {}
      for _, entry in ipairs(parsed) do
        local usage = nil
        if entry.response_json and type(entry.response_json) == 'table' then usage = entry.response_json.usage end

        table.insert(entries, {
          id = entry.id or '',
          conversation_id = entry.conversation_id or '',
          model = entry.model or '',
          prompt = entry.prompt or '',
          response = entry.response or '',
          system = entry.system,
          timestamp = entry.datetime_utc or '',
          usage = usage,
        })
      end

      callback(entries)
    end)
  end)
end

---@param callback fun(templates: string[]) Callback with list of template names.
---@return nil
Backend.get_templates_async = function(callback)
  vim.system({ H.config.cmd, 'templates', 'list' }, { text = true }, function(result)
    vim.schedule(function()
      local output = vim.split(result.stdout or '', '\n', { plain = true, trimempty = true })
      local templates = {}
      for _, line in ipairs(output) do
        if line:match('^%S+%s*:') then
          local name = line:match('^(%S+)%s*:')
          if name then table.insert(templates, name) end
        end
      end
      callback(templates)
    end)
  end)
end

---Get detailed information about a template (async).
---@param template_name string Name of the template.
---@param callback fun(template: table?) Callback with template data or nil.
---@return nil
Backend.get_template_async = function(template_name, callback)
  vim.system({ H.config.cmd, 'templates', 'show', template_name }, { text = true }, function(result)
    vim.schedule(function()
      local output = result.stdout or ''
      if output == '' then
        callback(nil)
        return
      end
      callback({
        name = template_name,
        content = output,
      })
    end)
  end)
end

---Get the templates directory path.
---@return string? Path to templates directory or nil.
Backend.get_templates_path = function() return H.get_templates_path() end

---Open the template file in Neovim for editing.
---@param template_name string Name of the template to edit.
---@return boolean Success status.
Backend.edit_template = function(template_name)
  local templates_path = H.get_templates_path()
  if not templates_path then return false end

  local template_file = templates_path .. '/' .. template_name .. '.yaml'
  if vim.fn.filereadable(template_file) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(template_file))
    return true
  end

  return false
end

---Parse token usage and cost from a stderr line.
---@param line string The stderr line to parse.
---@return table|nil A table with input, output, and cost (optional), or nil if not found.
Backend.parse_token_usage = function(line)
  local input, output = line:match('Token usage:%s*([%d,]+)%s+input,%s*([%d,]+)%s+output')
  if not input or not output then return nil end

  input = input:gsub(',', '')
  output = output:gsub(',', '')

  local result = { input = tonumber(input), output = tonumber(output), cost = 0 }

  local cost = line:match('"cost":%s*([%d%.eE%+%-]+)')
  if cost then result.cost = tonumber(cost) end

  return result
end

---Detect if a line is a Tool call header.
---@param line string The line to check.
---@return boolean True if the line is a Tool call header.
Backend.is_tool_call_header = function(line) return line:match('^Tool call:') ~= nil end

---Detect if a line is part of tool call output (indented lines after header).
---@param line string The line to check.
---@return boolean True if the line appears to be tool output.
Backend.is_tool_call_output = function(line) return line:match('^%s+') ~= nil end

return Backend
