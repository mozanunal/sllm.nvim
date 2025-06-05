local M = {}

M.extract_models = function()
  local models = vim.fn.systemlist('llm models')
  local only_models = {}
  for _, line in ipairs(models) do
    local model = line:match('^.-:%s*([^(%s]+)')
    if model then table.insert(only_models, model) end
  end
  return only_models
end

-- -- 2) tools inside each toolbox
-- if spec.toolboxes then
--   for _, box in ipairs(spec.toolboxes) do
--     if box.tools then
--       for _, tool in ipairs(box.tools) do
--         table.insert(names, tool.name)
--       end
--     end
--   end
-- end

M.extract_tools = function()
  local json_string = vim.fn.system("llm tools list --json")
  local spec = vim.fn.json_decode(json_string)
  local names = {}
  if spec.tools then
    for _, tool in ipairs(spec.tools) do
      table.insert(names, tool.name)
    end
  end
  return names
end


M.llm_cmd = function(user_input, continue, show_usage, model, ctx_files, tools)
  local cmd = 'llm'
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

  cmd = cmd .. ' ' .. vim.fn.shellescape(user_input)
  return cmd
end

return M
