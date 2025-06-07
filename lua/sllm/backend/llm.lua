---@module "sllm.backend.llm"
local M = {}

---Run `llm models` and parse out just the model names.
---@return string[]  List of available model names.
function M.extract_models()
  local models = vim.fn.systemlist('llm models')
  local only_models = {}
  for _, line in ipairs(models) do
    -- lines look like "0: model-name (description…)"
    local model = line:match('^.-:%s*([^(%s]+)')
    if model then table.insert(only_models, model) end
  end
  return only_models
end

---Run `llm tools list --json` and extract tool names.
---@return string[]  List of tool names.
function M.extract_tools()
  local json_string = vim.fn.system('llm tools list --json')
  local spec = vim.fn.json_decode(json_string)
  local names = {}
  if spec.tools then
    for _, tool in ipairs(spec.tools) do
      table.insert(names, tool.name)
    end
  end
  return names
end

---Construct the full `llm` command with provided options.
---
---@param user_input   string             The prompt text to send to LLM.
---@param continue     boolean?           Pass `-c` to continue a previous session.
---@param show_usage   boolean?           Pass `-u` to show usage examples.
---@param model        string?            Pass `-m <model>` to select a model.
---@param ctx_files    string[]?          Pass `-f <file>` for each context file.
---@param tools        string[]?          Pass `-T <tool>` for each tool.
---@param functions    string[]?          Pass `--functions <func>` for each function signature.
---@return string                      The assembled shell command.
function M.llm_cmd(user_input, continue, show_usage, model, ctx_files, tools, functions)
  local cmd = 'llm --td'
  if continue then cmd = cmd .. ' -c' end
  if show_usage then cmd = cmd .. ' -u' end
  if model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(model) end

  if ctx_files then
    for _, filename in ipairs(ctx_files) do
      cmd = cmd .. ' -f ' .. vim.fn.shellescape(filename) .. ' '
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
