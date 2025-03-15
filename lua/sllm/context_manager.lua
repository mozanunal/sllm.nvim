local M = {}

local context = {
  files = {},
  snips = {},
}

M.get = function() return context end

M.reset = function()
  context = {
    files = {},
    snips = {},
  }
end

M.add_file = function(filepath)
  local is_in_context = vim.tbl_contains(context.files, filepath)
  if not is_in_context then table.insert(context.files, filepath) end
end

M.add_snip = function(text, filepath, filetype)
  table.insert(context.snips, { filepath = filepath, filetype = filetype, text = vim.trim(text) })
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
  print(table.concat(vars, '\n'))
  return (template:gsub('%${(.-)}', function(key) return tostring(vars[key]) or '' end))
end

M.render_template = render_template

M.render_prompt_ui = function(user_input)
  -- Assemble files section
  local files_list = ''
  if #context.files > 0 then
    files_list = '\n### Files\n'
    for _, f in ipairs(context.files) do
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
