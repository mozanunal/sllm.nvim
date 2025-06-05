local M = {}

local context = {
  fragments = {},
  snips = {},
  tools = {},
  functions = {},
}

M.get = function() return context end

M.reset = function()
  context = {
    fragments = {},
    snips = {},
    tools = {},
    functions = {},
  }
end

M.add_fragment = function(filepath)
  local is_in_context = vim.tbl_contains(context.fragments, filepath)
  if not is_in_context then table.insert(context.fragments, filepath) end
end

M.add_snip = function(text, filepath, filetype)
  table.insert(context.snips, { filepath = filepath, filetype = filetype, text = vim.trim(text) })
end

M.add_tool = function(tool_name)
  local is_in_context = vim.tbl_contains(context.tools, tool_name)
  if not is_in_context then table.insert(context.tools, tool_name) end
end

M.add_function = function(func_str)
  local is_in_context = vim.tbl_contains(context.functions, func_str)
  if not is_in_context then table.insert(context.functions, func_str) end
end

local tmpl_snippet = [[From ${filepath}:

```${filetype}
${text}
```]]

local tmpl_files = [[- ${filepath}]]

local tmpl_prompt = [[${user_input}

${snippets}

${files}
]]

local function render_template(template, vars)
  return (template:gsub('%${(.-)}', function(key) return tostring(vars[key]) or '' end))
end

M.render_template = render_template

M.render_prompt_ui = function(user_input)
  -- Assemble files section
  local files_list = ''
  if #context.fragments > 0 then
    files_list = '\n### Fragments\n'
    for _, f in ipairs(context.fragments) do
      files_list = files_list .. render_template(tmpl_files, { filepath = f }) .. '\n'
    end
    files_list = files_list .. '\n'
  end

  -- Assemble snippets section
  local snip_list = ''
  if #context.snips > 0 then
    snip_list = '\n### Snippets\n'
    for _, snip in ipairs(context.snips) do
      snip_list = snip_list .. render_template(tmpl_snippet, snip) .. '\n\n'
    end
  end

  -- Remove trailing newlines and whitespace
  files_list = vim.trim(files_list)
  snip_list = vim.trim(snip_list)

  -- Final prompt assembly
  local prompt = render_template(tmpl_prompt, {
    user_input = user_input or '',
    files = files_list,
    snippets = snip_list,
  })
  return vim.trim(prompt)
end

return M
