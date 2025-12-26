---@module "sllm.history_manager"

---@class SllmHistoryEntry
---@field id string                    Unique log ID
---@field conversation_id string       Conversation ID
---@field model string                 Model name used
---@field prompt string                User's prompt
---@field response string              LLM's response
---@field system string?               System prompt used
---@field timestamp string             ISO timestamp
---@field usage table?                 Token usage information

-- Module definition ==========================================================
local HistoryManager = {}
local H = {}

-- Helper data ================================================================
H.utils = require('sllm.utils')

-- Helper functionality =======================================================
--- Execute a system command (can be mocked for testing).
---@param cmd string  Command to execute.
---@return string     Command output.
HistoryManager._system_exec = function(cmd) return vim.fn.system(cmd) end

--- Fetch history entries from llm logs.
---@param llm_cmd string         Command for the llm CLI.
---@param count integer?         Number of entries to fetch (default: 20).
---@param query string?          Search query to filter logs.
---@param model string?          Filter by model name.
---@return SllmHistoryEntry[]?  List of history entries or nil on error.
-- Public API =================================================================
function HistoryManager.fetch_history(llm_cmd, count, query, model)
  count = count or 20
  local cmd = llm_cmd .. ' logs list --json -n ' .. count

  if query then cmd = cmd .. ' -q ' .. vim.fn.shellescape(query) end

  if model then cmd = cmd .. ' -m ' .. vim.fn.shellescape(model) end

  local output = HistoryManager._system_exec(cmd)
  local parsed = H.utils.parse_json(output)

  if not parsed then return nil end

  local entries = {}
  for _, entry in ipairs(parsed) do
    -- Extract usage info, handling vim.NIL
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

--- Fetch all logs for a specific conversation ID.
---@param llm_cmd string             Command for the llm CLI.
---@param conversation_id string     Conversation ID to fetch.
---@return SllmHistoryEntry[]?      List of conversation entries or nil on error.
function HistoryManager.fetch_conversation(llm_cmd, conversation_id)
  local cmd = llm_cmd .. ' logs list --json --cid ' .. vim.fn.shellescape(conversation_id)
  local output = HistoryManager._system_exec(cmd)
  local parsed = H.utils.parse_json(output)

  if not parsed then return nil end

  local entries = {}
  for _, entry in ipairs(parsed) do
    -- Extract usage info, handling vim.NIL
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

--- Format a history entry for display in a picker.
---@param entry SllmHistoryEntry  History entry to format.
---@return string                 Formatted display string.
function HistoryManager.format_entry_for_picker(entry)
  local timestamp = entry.timestamp:gsub('T', ' '):gsub('Z', ''):sub(1, 19)
  local prompt_preview = entry.prompt:gsub('\n', ' '):sub(1, 60)
  if #entry.prompt > 60 then prompt_preview = prompt_preview .. '...' end
  return string.format('[%s] %s | %s', timestamp, entry.model, prompt_preview)
end

--- Format a conversation entry for display.
---@param entry SllmHistoryEntry  History entry to format.
---@return string[]               Lines to display in buffer.
function HistoryManager.format_conversation_entry(entry)
  local lines = {}
  local timestamp = entry.timestamp:gsub('T', ' '):gsub('Z', '')

  table.insert(lines, string.format('# %s', timestamp))
  table.insert(lines, string.format('**Model:** %s', entry.model))
  table.insert(lines, '')
  table.insert(lines, '## 💬 Prompt')
  table.insert(lines, '')

  for _, line in ipairs(vim.split(entry.prompt, '\n', { plain = true })) do
    table.insert(lines, line)
  end

  table.insert(lines, '')
  table.insert(lines, '## 🤖 Response')
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
---@param entries SllmHistoryEntry[]  List of history entries.
---@return table<string, integer>    Map of conversation_id to count.
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
