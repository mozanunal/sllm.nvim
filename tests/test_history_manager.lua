local MiniTest = require('mini.test')
local HistMan = require('sllm.history_manager')

local T = MiniTest.new_set({ name = 'history_manager' })

-- =============================================================================
-- fetch_history tests
-- =============================================================================

T['fetch_history'] = MiniTest.new_set()

T['fetch_history']['returns table of entries'] = function()
  local entries = HistMan.fetch_history('llm', 5)
  MiniTest.expect.equality(type(entries), 'table')
end

T['fetch_history']['handles vim.NIL in response_json'] = function()
  -- This test verifies the fix for vim.NIL userdata values
  local entries = HistMan.fetch_history('llm', 10)

  if entries and #entries > 0 then
    for _, entry in ipairs(entries) do
      -- All required fields should be strings
      MiniTest.expect.equality(type(entry.id), 'string')
      MiniTest.expect.equality(type(entry.conversation_id), 'string')
      MiniTest.expect.equality(type(entry.model), 'string')
      MiniTest.expect.equality(type(entry.prompt), 'string')
      MiniTest.expect.equality(type(entry.response), 'string')
      MiniTest.expect.equality(type(entry.timestamp), 'string')

      -- usage can be nil or table, but never userdata
      if entry.usage ~= nil then MiniTest.expect.equality(type(entry.usage), 'table') end
    end
  end
end

T['fetch_history']['respects count parameter'] = function()
  local entries_5 = HistMan.fetch_history('llm', 5)
  local entries_10 = HistMan.fetch_history('llm', 10)

  if entries_5 and entries_10 then
    MiniTest.expect.equality(#entries_5 <= 5, true)
    MiniTest.expect.equality(#entries_10 <= 10, true)
  end
end

-- =============================================================================
-- format_conversation_entry tests
-- =============================================================================

T['format_conversation_entry'] = MiniTest.new_set()

T['format_conversation_entry']['returns table of lines'] = function()
  local entries = HistMan.fetch_history('llm', 1)

  if entries and #entries > 0 then
    local formatted = HistMan.format_conversation_entry(entries[1])
    MiniTest.expect.equality(type(formatted), 'table')
    MiniTest.expect.equality(#formatted > 0, true)
  end
end

T['format_conversation_entry']['includes timestamp'] = function()
  local entries = HistMan.fetch_history('llm', 1)

  if entries and #entries > 0 then
    local formatted = HistMan.format_conversation_entry(entries[1])
    local has_timestamp = false

    for _, line in ipairs(formatted) do
      if line:find('#') then
        has_timestamp = true
        break
      end
    end

    MiniTest.expect.equality(has_timestamp, true)
  end
end

T['format_conversation_entry']['includes prompt and response sections'] = function()
  local entries = HistMan.fetch_history('llm', 1)

  if entries and #entries > 0 then
    local formatted = HistMan.format_conversation_entry(entries[1])
    local content = table.concat(formatted, '\n')

    MiniTest.expect.equality(content:find('Prompt') ~= nil, true)
    MiniTest.expect.equality(content:find('Response') ~= nil, true)
  end
end

T['format_conversation_entry']['handles entries without usage info'] = function()
  local mock_entry = {
    id = 'test-id',
    conversation_id = 'test-conv',
    model = 'test-model',
    prompt = 'test prompt',
    response = 'test response',
    timestamp = '2025-01-01T12:00:00.000000+00:00',
    usage = nil, -- No usage info
  }

  local formatted = HistMan.format_conversation_entry(mock_entry)
  MiniTest.expect.equality(type(formatted), 'table')
  MiniTest.expect.equality(#formatted > 0, true)
end

-- =============================================================================
-- format_entry_for_picker tests
-- =============================================================================

T['format_entry_for_picker'] = MiniTest.new_set()

T['format_entry_for_picker']['returns string'] = function()
  local mock_entry = {
    timestamp = '2025-01-01T12:00:00Z',
    model = 'gpt-4',
    prompt = 'test prompt',
  }

  local result = HistMan.format_entry_for_picker(mock_entry)
  MiniTest.expect.equality(type(result), 'string')
end

T['format_entry_for_picker']['includes timestamp and model'] = function()
  local mock_entry = {
    timestamp = '2025-01-01T12:00:00Z',
    model = 'test-model',
    prompt = 'test prompt',
  }

  local result = HistMan.format_entry_for_picker(mock_entry)
  MiniTest.expect.equality(result:find('2025%-01%-01') ~= nil, true)
  MiniTest.expect.equality(result:find('test%-model') ~= nil, true)
end

T['format_entry_for_picker']['truncates long prompts'] = function()
  local long_prompt = string.rep('a', 100)
  local mock_entry = {
    timestamp = '2025-01-01T12:00:00Z',
    model = 'test-model',
    prompt = long_prompt,
  }

  local result = HistMan.format_entry_for_picker(mock_entry)
  -- Should be truncated to 60 chars + "..."
  MiniTest.expect.equality(result:find('%.%.%.') ~= nil, true)
  MiniTest.expect.equality(#result < #long_prompt, true)
end

-- =============================================================================
-- get_conversations tests
-- =============================================================================

T['get_conversations'] = MiniTest.new_set()

T['get_conversations']['groups entries by conversation_id'] = function()
  local mock_entries = {
    { conversation_id = 'conv-1', id = 'msg-1' },
    { conversation_id = 'conv-1', id = 'msg-2' },
    { conversation_id = 'conv-2', id = 'msg-3' },
  }

  local convs = HistMan.get_conversations(mock_entries)
  MiniTest.expect.equality(type(convs), 'table')
  MiniTest.expect.equality(convs['conv-1'], 2)
  MiniTest.expect.equality(convs['conv-2'], 1)
end

T['get_conversations']['ignores empty conversation_ids'] = function()
  local mock_entries = {
    { conversation_id = '', id = 'msg-1' },
    { conversation_id = 'conv-1', id = 'msg-2' },
  }

  local convs = HistMan.get_conversations(mock_entries)
  MiniTest.expect.equality(convs[''], nil)
  MiniTest.expect.equality(convs['conv-1'], 1)
end

return T
