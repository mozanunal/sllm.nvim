---@module "sllm.backend.llm"
--- LLM CLI backend for sllm.
--- Wraps Simon Willison's llm CLI tool.

-- Module definition ==========================================================
local Llm = { name = 'llm' }
local H = {}

-- Helper data ================================================================

-- Parse JSON string safely with error handling.
H.parse_json = function(json_str)
  local ok, result = pcall(vim.fn.json_decode, json_str)
  if ok then
    return result
  else
    return nil
  end
end

-- Get the templates directory path.
H.get_templates_path = function(llm_cmd)
  local output = vim.fn.system({ llm_cmd, 'templates', 'path' })
  local path = vim.trim(output)
  if path ~= '' and path:sub(1, 5) ~= 'Error' then return path end
  return nil
end

-- Check if a file should be treated as an attachment (image, PDF, etc.)
H.is_attachment = function(filename)
  local attachment_extensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
    'svg',
    'ico',
    'tiff',
    'tif',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'mp3',
    'mp4',
    'wav',
    'avi',
    'mov',
    'mkv',
    'flac',
    'ogg',
    'zip',
    'tar',
    'gz',
    'rar',
    '7z',
  }

  local ext = filename:match('%.([^%.]+)$')
  if ext then
    ext = ext:lower()
    for _, attach_ext in ipairs(attachment_extensions) do
      if ext == attach_ext then return true end
    end
  end
  return false
end

-- Public API =================================================================

---Get list of available models from llm CLI.
---@param config table Backend configuration with cmd field.
---@return string[] List of model names.
Llm.get_models = function(config)
  local llm_cmd = config.cmd or 'llm'
  local models = vim.fn.systemlist({ llm_cmd, 'models' })
  local only_models = {}
  for _, line in ipairs(models) do
    local model = line:match('^.-:%s*([^(%s]+)')
    if model then table.insert(only_models, model) end
  end
  return only_models
end

---Get the default model name from llm CLI.
---@param config table Backend configuration with cmd field.
---@return string Default model name.
Llm.get_default_model = function(config)
  local llm_cmd = config.cmd or 'llm'
  local output = vim.fn.system({ llm_cmd, 'models', 'default' })
  return output:match('(.-)%s*$')
end

---Get model-specific options.
---@param config table Backend configuration with cmd field.
---@param model string Model name.
---@return string[] List of options description lines.
Llm.get_model_options = function(config, model)
  local llm_cmd = config.cmd or 'llm'
  return vim.fn.systemlist({ llm_cmd, 'models', '--options', '-m', model })
end

---Get list of available tools from llm CLI.
---@param config table Backend configuration with cmd field.
---@return string[] List of tool names.
Llm.get_tools = function(config)
  local llm_cmd = config.cmd or 'llm'
  local json_string = vim.fn.system({ llm_cmd, 'tools', 'list', '--json' })
  local spec = H.parse_json(json_string)
  local names = {}
  if spec and spec.tools then
    for _, tool in ipairs(spec.tools) do
      table.insert(names, tool.name)
    end
  end
  return names
end

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

---Build the llm CLI command string or table.
---@param config table Backend configuration with cmd field.
---@param options LlmBuildCommandOptions Command options.
---@return string[] The assembled shell command.
Llm.build_command = function(config, options)
  local llm_cmd = config.cmd or 'llm'
  local cmd = { llm_cmd }

  if not options.prompt then error('prompt is required') end

  -- Add tool flags unless raw mode is requested
  if not options.raw then
    table.insert(cmd, '--td')
    table.insert(cmd, '--cl')
    table.insert(cmd, tostring(options.chain_limit or 100))
  end

  if options.no_stream then table.insert(cmd, '--no-stream') end

  if type(options.continue) == 'string' then
    table.insert(cmd, '--cid')
    table.insert(cmd, options.continue)
  elseif options.continue then
    table.insert(cmd, '-c')
  end

  if options.show_usage then table.insert(cmd, '-u') end
  if options.model then
    table.insert(cmd, '-m')
    table.insert(cmd, options.model)
  end

  if options.ctx_files then
    for _, filename in ipairs(options.ctx_files) do
      local flag = H.is_attachment(filename) and '-a' or '-f'
      table.insert(cmd, flag)
      table.insert(cmd, filename)
    end
  end

  if options.tools then
    for _, tool_name in ipairs(options.tools) do
      table.insert(cmd, '-T')
      table.insert(cmd, tool_name)
    end
  end

  if options.functions then
    for _, func_str in ipairs(options.functions) do
      table.insert(cmd, '--functions')
      table.insert(cmd, func_str)
    end
  end

  if options.online then
    table.insert(cmd, '-o')
    table.insert(cmd, 'online')
    table.insert(cmd, '1')
  end
  if options.system_prompt then
    table.insert(cmd, '-s')
    table.insert(cmd, options.system_prompt)
  end

  if options.model_options then
    for key, value in pairs(options.model_options) do
      table.insert(cmd, '-o')
      table.insert(cmd, key)
      table.insert(cmd, tostring(value))
    end
  end

  if options.template then
    table.insert(cmd, '-t')
    table.insert(cmd, options.template)
  end

  -- Use -- to end options parsing (prompt may start with dashes)
  table.insert(cmd, '--')
  table.insert(cmd, options.prompt)

  return cmd
end

---LLM CLI backend supports tool calling.
---@return boolean True
Llm.supports_tools = function() return true end

---LLM CLI supports history.
---@return boolean True.
Llm.supports_history = function() return true end

---LLM CLI supports templates.
---@return boolean True.
Llm.supports_templates = function() return true end

---Fetch history entries from llm logs.
---@param config table Backend configuration with cmd field.
---@param options table? History options.
---@return table[]? List of history entries or nil.
Llm.get_history = function(config, options)
  options = options or {}
  local llm_cmd = config.cmd or 'llm'
  local count = options.count or 20
  local cmd = { llm_cmd, 'logs', 'list', '--json', '-n', tostring(count) }

  if options.query then
    table.insert(cmd, '-q')
    table.insert(cmd, options.query)
  end
  if options.model then
    table.insert(cmd, '-m')
    table.insert(cmd, options.model)
  end

  local output = vim.fn.system(cmd)
  local parsed = H.parse_json(output)

  if not parsed then return nil end

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

  return entries
end

---Fetch all logs for a specific conversation ID.
---@param config table Backend configuration with cmd field.
---@param conversation_id string Conversation ID to fetch.
---@return table[]? List of conversation entries or nil.
Llm.get_session = function(config, conversation_id)
  local llm_cmd = config.cmd or 'llm'
  local cmd = { llm_cmd, 'logs', 'list', '--json', '--cid', conversation_id }
  local output = vim.fn.system(cmd)
  local parsed = H.parse_json(output)

  if not parsed then return nil end

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

  return entries
end

---Fetch the last conversation ID.
---@param config table Backend configuration with cmd field.
---@return string? conversation_id or nil.
Llm.get_last_conversation_id = function(config)
  local llm_cmd = config.cmd or 'llm'
  local cmd = { llm_cmd, 'logs', 'list', '--json', '-n', '1' }
  local output = vim.fn.system(cmd)
  local parsed = H.parse_json(output)
  if not parsed or #parsed == 0 then return nil end
  return parsed[1].conversation_id
end

---Get list of available templates from llm CLI.
---@param config table Backend configuration with cmd field.
---@return string[] List of template names.
Llm.get_templates = function(config)
  local llm_cmd = config.cmd or 'llm'
  local output = vim.fn.systemlist({ llm_cmd, 'templates', 'list' })

  local templates = {}
  for _, line in ipairs(output) do
    if line:match('^%S+%s*:') then
      local name = line:match('^(%S+)%s*:')
      if name then table.insert(templates, name) end
    end
  end

  return templates
end

---Get detailed information about a template.
---@param config table Backend configuration with cmd field.
---@param template_name string Name of the template.
---@return table? Template data (yaml content) or nil.
Llm.get_template = function(config, template_name)
  local llm_cmd = config.cmd or 'llm'
  local output = vim.fn.system({ llm_cmd, 'templates', 'show', template_name })

  if output == '' then return nil end

  return {
    name = template_name,
    content = output,
  }
end

---Get the templates directory path.
---@param config table Backend configuration with cmd field.
---@return string? Path to templates directory or nil.
Llm.get_templates_path = function(config)
  local llm_cmd = config.cmd or 'llm'
  return H.get_templates_path(llm_cmd)
end

---Open the template file in Neovim for editing.
---@param config table Backend configuration with cmd field.
---@param template_name string Name of the template to edit.
---@return boolean Success status.
Llm.edit_template = function(config, template_name)
  local llm_cmd = config.cmd or 'llm'
  local templates_path = H.get_templates_path(llm_cmd)
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
Llm.parse_token_usage = function(line)
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
Llm.is_tool_call_header = function(line) return line:match('^Tool call:') ~= nil end

---Detect if a line is part of tool call output (indented lines after header).
---@param line string The line to check.
---@return boolean True if the line appears to be tool output.
Llm.is_tool_call_output = function(line) return line:match('^%s+') ~= nil end

return Llm
