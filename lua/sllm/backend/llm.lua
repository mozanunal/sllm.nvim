---@module "sllm.backend.llm"
--- LLM CLI backend implementation for sllm.
--- Wraps Simon Willison's llm CLI tool.

-- Module definition ==========================================================
local Base = require('sllm.backend.base')
local H = {}

-- Helper data ================================================================
--- Parse JSON string safely with error handling.
---@param json_str string  JSON string to parse.
---@return table?  Parsed table or nil on error.
H.parse_json = function(json_str)
  local ok, result = pcall(vim.fn.json_decode, json_str)
  if ok then
    return result
  else
    return nil
  end
end

---Get the templates directory path.
---@param llm_cmd string LLM command path.
---@return string? Path to templates directory or nil.
H.get_templates_path = function(llm_cmd)
  local output = vim.fn.system(llm_cmd .. ' templates path')
  local path = vim.trim(output)
  if path ~= '' and path:sub(1, 5) ~= 'Error' then return path end
  return nil
end

---Check if a file should be treated as an attachment (image, PDF, etc.)
---@param filename string File path to check.
---@return boolean True if the file should use `-a`, false if it should use `-f`.
H.is_attachment = function(filename)
  local attachment_extensions = {
    -- Images
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
    -- Documents
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    -- Audio/Video
    'mp3',
    'mp4',
    'wav',
    'avi',
    'mov',
    'mkv',
    'flac',
    'ogg',
    -- Archives
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

--- Parse token usage and cost from a stderr line.
--- Expected format: "Token usage: 123 input, 456 output" or
---                  "Token usage: 123 input, 456 output, {..., "cost": 0.001234, ...}"
---@param line string The stderr line to parse
---@return table|nil A table with input, output, and cost (optional), or nil if not found
H.parse_token_usage = function(line)
  local input, output = line:match('Token usage:%s*([%d,]+)%s+input,%s*([%d,]+)%s+output')
  if not input or not output then return nil end

  input = input:gsub(',', '')
  output = output:gsub(',', '')

  local result = { input = tonumber(input), output = tonumber(output), cost = 0 }

  -- Try to extract cost from JSON-like format
  local cost = line:match('"cost":%s*([%d%.eE%+%-]+)')
  if cost then result.cost = tonumber(cost) end

  return result
end

--- Detect if a line is part of tool call output.
--- Tool call outputs start with "Tool call:" and can be followed by function names.
---@param line string The stderr line to check
---@return boolean True if the line appears to be tool call related
H.is_tool_call_output = function(line)
  return line:match('^Tool call:') ~= nil or line:match('^%s*[📁📄🔧]') ~= nil
end

-- Backend Implementation =====================================================
local LlmBackend = Base.extend({
  ---Backend identifier.
  name = 'llm',

  ---Get list of available models from llm CLI.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@return string[] List of model names.
  get_models = function(config)
    local llm_cmd = config.cmd or 'llm'
    local models = vim.fn.systemlist(llm_cmd .. ' models')
    local only_models = {}
    for _, line in ipairs(models) do
      -- lines look like "0: model-name (description...)"
      local model = line:match('^.-:%s*([^(%s]+)')
      if model then table.insert(only_models, model) end
    end
    return only_models
  end,

  ---Get the default model name from llm CLI.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@return string Default model name.
  get_default_model = function(config)
    local llm_cmd = config.cmd or 'llm'
    local output = vim.fn.system(llm_cmd .. ' models default')
    -- remove trailing whitespace: the output includes a newline at its end
    return output:match('(.-)%s*$')
  end,

  ---Get list of available tools from llm CLI.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@return string[] List of tool names.
  get_tools = function(config)
    local llm_cmd = config.cmd or 'llm'
    local json_string = vim.fn.system(llm_cmd .. ' tools list --json')
    local spec = H.parse_json(json_string)
    local names = {}
    if spec and spec.tools then
      for _, tool in ipairs(spec.tools) do
        table.insert(names, tool.name)
      end
    end
    return names
  end,

  ---Build the llm CLI command string.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@param options BackendCommandOptions Command options.
  ---@return string The assembled shell command.
  build_command = function(config, options)
    local llm_cmd = config.cmd or 'llm'
    local cmd = llm_cmd .. ' --td --cl ' .. (options.chain_limit or 100)

    -- Handle continuation: string = conversation ID, true = continue last, false/nil = new
    if type(options.continue) == 'string' then
      cmd = cmd .. ' --cid ' .. vim.fn.shellescape(options.continue)
    elseif options.continue then
      cmd = cmd .. ' -c'
    end

    if options.show_usage then cmd = cmd .. ' -u' end
    if options.model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(options.model) end

    if options.ctx_files then
      for _, filename in ipairs(options.ctx_files) do
        -- Use -a for attachments (images, PDFs, etc.), -f for text files
        local flag = H.is_attachment(filename) and '-a' or '-f'
        cmd = cmd .. ' ' .. flag .. ' ' .. vim.fn.shellescape(filename) .. ' '
      end
    end

    if options.tools then
      for _, tool_name in ipairs(options.tools) do
        cmd = cmd .. ' -T ' .. vim.fn.shellescape(tool_name) .. ' '
      end
    end

    if options.functions then
      for _, func_str in ipairs(options.functions) do
        cmd = cmd .. ' --functions ' .. vim.fn.shellescape(func_str) .. ' '
      end
    end

    if options.online then cmd = cmd .. ' -o online 1' end

    if options.system_prompt then cmd = cmd .. ' -s ' .. vim.fn.shellescape(options.system_prompt) end

    if options.model_options then
      for key, value in pairs(options.model_options) do
        cmd = cmd .. ' -o ' .. vim.fn.shellescape(key) .. ' ' .. vim.fn.shellescape(tostring(value))
      end
    end

    if options.template then cmd = cmd .. ' -t ' .. vim.fn.shellescape(options.template) end

    -- Always append the user's input prompt at the end
    cmd = cmd .. ' ' .. vim.fn.shellescape(options.prompt)
    return cmd
  end,

  ---LLM CLI supports tool calling.
  ---@return boolean True.
  supports_tools = function() return true end,

  ---LLM CLI supports history.
  ---@return boolean True.
  supports_history = function() return true end,

  ---LLM CLI supports templates.
  ---@return boolean True.
  supports_templates = function() return true end,

  ---Fetch history entries from llm logs.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@param options BackendHistoryOptions? History options.
  ---@return BackendHistoryEntry[]? List of history entries or nil.
  get_history = function(config, options)
    options = options or {}
    local llm_cmd = config.cmd or 'llm'
    local count = options.count or 20
    local cmd = llm_cmd .. ' logs list --json -n ' .. count

    if options.query then cmd = cmd .. ' -q ' .. vim.fn.shellescape(options.query) end
    if options.model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(options.model) end

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
  end,

  ---Fetch all logs for a specific conversation ID.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@param conversation_id string Conversation ID to fetch.
  ---@return BackendHistoryEntry[]? List of conversation entries or nil.
  get_session = function(config, conversation_id)
    local llm_cmd = config.cmd or 'llm'
    local cmd = llm_cmd .. ' logs list --json --cid ' .. vim.fn.shellescape(conversation_id)
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
  end,

  ---Get list of available templates from llm CLI.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@return string[] List of template names.
  get_templates = function(config)
    local llm_cmd = config.cmd or 'llm'
    local output = vim.fn.systemlist(llm_cmd .. ' templates list')

    local templates = {}
    for _, line in ipairs(output) do
      if line:match('^%S+%s*:') then
        local name = line:match('^(%S+)%s*:')
        if name then table.insert(templates, name) end
      end
    end

    return templates
  end,

  ---Get detailed information about a template.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@param template_name string Name of the template.
  ---@return table? Template data (yaml content) or nil.
  get_template = function(config, template_name)
    local llm_cmd = config.cmd or 'llm'
    local output = vim.fn.system(llm_cmd .. ' templates show ' .. vim.fn.shellescape(template_name))

    if output == '' then return nil end

    return {
      name = template_name,
      content = output,
    }
  end,

  ---Get the templates directory path.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@return string? Path to templates directory or nil.
  get_templates_path = function(config)
    local llm_cmd = config.cmd or 'llm'
    return H.get_templates_path(llm_cmd)
  end,

  ---Open the template file in Neovim for editing.
  ---@param config BackendConfig Backend configuration with cmd field.
  ---@param template_name string Name of the template to edit.
  ---@return boolean Success status.
  edit_template = function(config, template_name)
    local llm_cmd = config.cmd or 'llm'
    local templates_path = H.get_templates_path(llm_cmd)
    if not templates_path then return false end

    local template_file = templates_path .. '/' .. template_name .. '.yaml'
    if vim.fn.filereadable(template_file) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(template_file))
      return true
    end

    return false
  end,

  ---Parse token usage and cost from a stderr line.
  ---@param line string The stderr line to parse.
  ---@return table|nil A table with input, output, and cost (optional), or nil if not found.
  parse_token_usage = function(line) return H.parse_token_usage(line) end,

  ---Detect if a line is part of tool call output.
  ---@param line string The stderr line to check.
  ---@return boolean True if the line appears to be tool call related.
  is_tool_call_output = function(line) return H.is_tool_call_output(line) end,
})

return LlmBackend
