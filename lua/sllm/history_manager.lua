---@module "sllm.history_manager"
--- History formatting utilities for sllm.
--- Data fetching is handled by the backend module.

-- Module definition ==========================================================
local HistoryManager = {}

-- Public API =================================================================

--- Format a history entry for display in a picker.
---@param entry BackendHistoryEntry History entry to format.
---@return string Formatted display string.
function HistoryManager.format_entry_for_picker(entry)
  local timestamp = entry.timestamp:gsub('T', ' '):gsub('Z', ''):sub(1, 19)
  local prompt_preview = entry.prompt:gsub('\n', ' '):sub(1, 60)
  if #entry.prompt > 60 then prompt_preview = prompt_preview .. '...' end
  return string.format('[%s] %s | %s', timestamp, entry.model, prompt_preview)
end

--- Format a conversation entry for display.
---@param entry BackendHistoryEntry History entry to format.
---@param ui_config table? UI configuration with prompt/response headers.
---@return string[] Lines to display in buffer.
function HistoryManager.format_conversation_entry(entry, ui_config)
  ui_config = ui_config or {}
  local prompt_header = ui_config.markdown_prompt_header or '## 💬 Prompt'
  local response_header = ui_config.markdown_response_header or '## 🤖 Response'

  local lines = {}
  local timestamp = entry.timestamp:gsub('T', ' '):gsub('Z', '')

  table.insert(lines, string.format('# %s', timestamp))
  table.insert(lines, string.format('**Model:** %s', entry.model))
  table.insert(lines, '')
  table.insert(lines, prompt_header)
  table.insert(lines, '')

  for _, line in ipairs(vim.split(entry.prompt, '\n', { plain = true })) do
    table.insert(lines, line)
  end

  table.insert(lines, '')
  table.insert(lines, response_header)
  table.insert(lines, '')

  for _, line in ipairs(vim.split(entry.response, '\n', { plain = true })) do
    table.insert(lines, line)
  end

  if entry.usage then
    table.insert(lines, '')
    table.insert(lines, '---')
    table.insert(
      lines,
      string.format(
        'Tokens: %s input / %s output',
        entry.usage.prompt_tokens or 'N/A',
        entry.usage.completion_tokens or 'N/A'
      )
    )
  end

  table.insert(lines, '')
  table.insert(lines, '---')
  table.insert(lines, '')

  return lines
end

--- Get unique conversation IDs from history entries.
---@param entries BackendHistoryEntry[] List of history entries.
---@return table<string, integer> Map of conversation_id to count.
function HistoryManager.get_conversations(entries)
  local conversations = {}
  for _, entry in ipairs(entries) do
    if entry.conversation_id and entry.conversation_id ~= '' then
      conversations[entry.conversation_id] = (conversations[entry.conversation_id] or 0) + 1
    end
  end
  return conversations
end

return HistoryManager
