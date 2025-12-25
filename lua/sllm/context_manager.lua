---@class SllmSnippet
---@field filepath string   Path of the source file.
---@field filetype string   Filetype/language of the snippet.
---@field text string       The snippet text (trimmed).
---
---@class SllmContext
---@field fragments string[]               List of file paths ("fragments").
---@field snips SllmSnippet[]             List of code snippets.
---@field tools string[]                   List of tool names.
---@field functions string[]               List of function definitions or signatures.

-- Module definition ==========================================================
local ContextManager = {}
local H = {}

-- Helper data ================================================================
H.utils = require('sllm.utils')

-- Module state
H.context = {
  fragments = {},
  snips = {},
  tools = {},
  functions = {},
}

-- Public API =================================================================
---Get the current context (fragments, snippets, tools, functions).
---@return SllmContext  The context table.
function ContextManager.get() return H.context end

---Reset the context to empty lists.
---@return nil
function ContextManager.reset()
  H.context = {
    fragments = {},
    snips = {},
    tools = {},
    functions = {},
  }
end

---Add a file path to the fragments list, if not already present.
---@param filepath string  Path to a fragment file.
---@return nil
function ContextManager.add_fragment(filepath)
  local is_in_context = vim.tbl_contains(H.context.fragments, filepath)
  if not is_in_context then table.insert(H.context.fragments, filepath) end
end

---Add a snippet entry to the context.
---@param text string       Snippet text (will be trimmed).
---@param filepath string   Source file path for the snippet.
---@param filetype string   Filetype/language of the snippet.
---@return nil
function ContextManager.add_snip(text, filepath, filetype)
  table.insert(H.context.snips, {
    filepath = filepath,
    filetype = filetype,
    text = vim.trim(text),
  })
end

---Add a tool name to the tools list, if not already present.
---@param tool_name string  Name of the tool.
---@return nil
function ContextManager.add_tool(tool_name)
  local is_in_context = vim.tbl_contains(H.context.tools, tool_name)
  if not is_in_context then table.insert(H.context.tools, tool_name) end
end

---Add a function representation to the functions list, if not already present.
---@param func_str string   Function source or signature as a string.
---@return nil
function ContextManager.add_function(func_str)
  local is_in_context = vim.tbl_contains(H.context.functions, func_str)
  if not is_in_context then table.insert(H.context.functions, func_str) end
end

---Assemble the full prompt UI, including file list and code snippets.
---@param user_input string?  Optional user input (empty string if `nil`).
---@return string             Trimmed prompt text to send to the LLM.
function ContextManager.render_prompt_ui(user_input)
  -- Assemble files section
  local files_list = ''
  if #H.context.fragments > 0 then
    files_list = '\n### Fragments\n'
    for _, f in ipairs(H.context.fragments) do
      files_list = files_list .. H.utils.render('- ${filepath}', { filepath = H.utils.get_relpath(f) }) .. '\n'
    end
    files_list = files_list .. '\n'
  end

  -- Assemble snippets section
  local snip_list = ''
  if #H.context.snips > 0 then
    snip_list = '\n### Snippets\n'
    for _, snip in ipairs(H.context.snips) do
      snip_list = snip_list
        .. H.utils.render('From ${filepath}:\n```' .. snip.filetype .. '\n${text}\n```', snip)
        .. '\n\n'
    end
  end

  -- Trim sections
  files_list = vim.trim(files_list)
  snip_list = vim.trim(snip_list)

  -- Final prompt template
  local tmpl_prompt = [[
${user_input}

${snippets}

${files}
]]
  local prompt = H.utils.render(tmpl_prompt, {
    user_input = user_input or '',
    snippets = snip_list,
    files = files_list,
  })
  return vim.trim(prompt)
end

return ContextManager
