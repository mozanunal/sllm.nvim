---@module "sllm.backend.llm"
local M = {}

---Run `llm models` and parse out just the model names.
---@param llm_cmd string Command to run the LLM CLI.
---@return string[]  List of available model names.
function M.extract_models(llm_cmd)
  local models = vim.fn.systemlist(llm_cmd .. ' models')
  local only_models = {}
  for _, line in ipairs(models) do
    -- lines look like "0: model-name (description…)"
    local model = line:match('^.-:%s*([^(%s]+)')
    if model then table.insert(only_models, model) end
  end
  return only_models
end

---Run `llm models default` and return the default model name.
---@param llm_cmd string Command to run the LLM CLI.
---@return string List of available model names.
function M.get_default_model(llm_cmd)
  local output = vim.fn.system(llm_cmd .. ' models default')
  -- remove trailing whitespace: the output includes a newline at its end
  return output:match('(.-)%s*$')
end

---Run `llm tools list --json` and extract tool names.
---@param llm_cmd string Command to run the LLM CLI.
---@return string[]  List of tool names.
function M.extract_tools(llm_cmd)
  local json_string = vim.fn.system(llm_cmd .. ' tools list --json')
  local spec = vim.fn.json_decode(json_string)
  local names = {}
  if spec.tools then
    for _, tool in ipairs(spec.tools) do
      table.insert(names, tool.name)
    end
  end
  return names
end

---Check if a file should be treated as an attachment (image, PDF, etc.)
---@param filename string File path to check.
---@return boolean True if the file should use `-a`, false if it should use `-f`.
local function is_attachment(filename)
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

---Construct the full `llm` command with provided options.
---
---@param llm_cmd        string             The base command to run `llm`.
---@param user_input     string             The prompt text to send to LLM.
---@param continue       boolean?           Pass `-c` to continue a previous session.
---@param show_usage     boolean?           Pass `-u` to show usage examples.
---@param model          string?            Pass `-m <model>` to select a model.
---@param ctx_files      string[]?          Pass `-f <file>` for each context file.
---@param tools          string[]?          Pass `-T <tool>` for each tool.
---@param functions      string[]?          Pass `--functions <func>` for each function signature.
---@param system_prompt  string?            Pass `-s <prompt>` for system prompt.
---@return string                        The assembled shell command.
function M.llm_cmd(llm_cmd, user_input, continue, show_usage, model, ctx_files, tools, functions, system_prompt)
  local cmd = llm_cmd .. ' --td'
  if continue then cmd = cmd .. ' -c' end
  if show_usage then cmd = cmd .. ' -u' end
  if model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(model) end

  if system_prompt and system_prompt ~= '' then cmd = cmd .. ' -s ' .. vim.fn.shellescape(system_prompt) end

  if ctx_files then
    for _, filename in ipairs(ctx_files) do
      -- Use -a for attachments (images, PDFs, etc.), -f for text files
      local flag = is_attachment(filename) and '-a' or '-f'
      cmd = cmd .. ' ' .. flag .. ' ' .. vim.fn.shellescape(filename) .. ' '
    end
  end

  if tools then
    for _, tool_name in ipairs(tools) do
      cmd = cmd .. ' -T ' .. vim.fn.shellescape(tool_name) .. ' '
    end
  end

  if functions then
    for _, func_str in ipairs(functions) do
      cmd = cmd .. ' --functions ' .. vim.fn.shellescape(func_str) .. ' '
    end
  end

  -- Always append the user's input prompt at the end
  cmd = cmd .. ' ' .. vim.fn.shellescape(user_input)
  return cmd
end

return M
