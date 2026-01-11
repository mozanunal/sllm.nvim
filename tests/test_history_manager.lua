local MiniTest = require('mini.test')
local HistMan = require('sllm.history_manager')

local T = MiniTest.new_set({ name = 'history_manager' })

-- =============================================================================
-- Test helpers
-- =============================================================================

--- Create a mock history entry
local function create_mock_entry(opts)
  opts = opts or {}
  return {
    id = opts.id or 'test-id',
    conversation_id = opts.conversation_id or 'test-conv',
    model = opts.model or 'gpt-4',
    prompt = opts.prompt or 'Test prompt',
    response = opts.response or 'Test response',
    system = opts.system,
    timestamp = opts.timestamp or '2025-01-01T12:00:00.000000+00:00',
    usage = opts.usage,
  }
end

-- =============================================================================
-- format_conversation_entry tests
-- =============================================================================

T['format_conversation_entry'] = MiniTest.new_set()

T['format_conversation_entry']['returns table of lines'] = function()
  local entry = create_mock_entry()
  local formatted = HistMan.format_conversation_entry(entry)
  MiniTest.expect.equality(type(formatted), 'table')
  MiniTest.expect.equality(#formatted > 0, true)
end

T['format_conversation_entry']['includes timestamp'] = function()
  local entry = create_mock_entry({ timestamp = '2025-06-15T14:30:00Z' })
  local formatted = HistMan.format_conversation_entry(entry)
  local has_timestamp = false

  for _, line in ipairs(formatted) do
    if line:find('2025%-06%-15') then
      has_timestamp = true
      break
    end
  end

  MiniTest.expect.equality(has_timestamp, true)
end

T['format_conversation_entry']['includes model'] = function()
  local entry = create_mock_entry({ model = 'claude-3' })
  local formatted = HistMan.format_conversation_entry(entry)
  local content = table.concat(formatted, '\n')
  MiniTest.expect.equality(content:find('claude%-3') ~= nil, true)
end

T['format_conversation_entry']['includes prompt and response sections'] = function()
  local entry = create_mock_entry()
  local formatted = HistMan.format_conversation_entry(entry)
  local content = table.concat(formatted, '\n')

  MiniTest.expect.equality(content:find('Prompt') ~= nil, true)
  MiniTest.expect.equality(content:find('Response') ~= nil, true)
end

T['format_conversation_entry']['includes prompt content'] = function()
  local entry = create_mock_entry({ prompt = 'My specific question here' })
  local formatted = HistMan.format_conversation_entry(entry)
  local content = table.concat(formatted, '\n')
  MiniTest.expect.equality(content:find('My specific question here') ~= nil, true)
end

T['format_conversation_entry']['includes response content'] = function()
  local entry = create_mock_entry({ response = 'The answer is 42' })
  local formatted = HistMan.format_conversation_entry(entry)
  local content = table.concat(formatted, '\n')
  MiniTest.expect.equality(content:find('The answer is 42') ~= nil, true)
end

T['format_conversation_entry']['handles entries without usage info'] = function()
  local entry = create_mock_entry({ usage = nil })
  local formatted = HistMan.format_conversation_entry(entry)
  MiniTest.expect.equality(type(formatted), 'table')
  MiniTest.expect.equality(#formatted > 0, true)
end

T['format_conversation_entry']['includes usage info when present'] = function()
  local entry = create_mock_entry({
    usage = { prompt_tokens = 100, completion_tokens = 200 },
  })
  local formatted = HistMan.format_conversation_entry(entry)
  local content = table.concat(formatted, '\n')
  MiniTest.expect.equality(content:find('100') ~= nil, true)
  MiniTest.expect.equality(content:find('200') ~= nil, true)
end

T['format_conversation_entry']['uses custom ui_config headers'] = function()
  local entry = create_mock_entry()
  local formatted = HistMan.format_conversation_entry(entry, {
    markdown_prompt_header = '## Custom Prompt Header',
    markdown_response_header = '## Custom Response Header',
  })
  local content = table.concat(formatted, '\n')
  MiniTest.expect.equality(content:find('Custom Prompt Header') ~= nil, true)
  MiniTest.expect.equality(content:find('Custom Response Header') ~= nil, true)
end

-- =============================================================================
-- format_entry_for_picker tests
-- =============================================================================

T['format_entry_for_picker'] = MiniTest.new_set()

T['format_entry_for_picker']['returns string'] = function()
  local entry = create_mock_entry()
  local result = HistMan.format_entry_for_picker(entry)
  MiniTest.expect.equality(type(result), 'string')
end

T['format_entry_for_picker']['includes timestamp and model'] = function()
  local entry = create_mock_entry({
    timestamp = '2025-01-01T12:00:00Z',
    model = 'test-model',
  })

  local result = HistMan.format_entry_for_picker(entry)
  MiniTest.expect.equality(result:find('2025%-01%-01') ~= nil, true)
  MiniTest.expect.equality(result:find('test%-model') ~= nil, true)
end

T['format_entry_for_picker']['includes prompt preview'] = function()
  local entry = create_mock_entry({ prompt = 'Hello world' })
  local result = HistMan.format_entry_for_picker(entry)
  MiniTest.expect.equality(result:find('Hello world') ~= nil, true)
end

T['format_entry_for_picker']['truncates long prompts'] = function()
  local long_prompt = string.rep('a', 100)
  local entry = create_mock_entry({ prompt = long_prompt })

  local result = HistMan.format_entry_for_picker(entry)
  -- Should be truncated to 60 chars + "..."
  MiniTest.expect.equality(result:find('%.%.%.') ~= nil, true)
  MiniTest.expect.equality(#result < #long_prompt, true)
end

T['format_entry_for_picker']['replaces newlines in prompt'] = function()
  local entry = create_mock_entry({ prompt = 'Line 1\nLine 2\nLine 3' })
  local result = HistMan.format_entry_for_picker(entry)
  MiniTest.expect.equality(result:find('\n'), nil)
end

-- =============================================================================
-- get_conversations tests
-- =============================================================================

T['get_conversations'] = MiniTest.new_set()

T['get_conversations']['groups entries by conversation_id'] = function()
  local entries = {
    create_mock_entry({ conversation_id = 'conv-1', id = 'msg-1' }),
    create_mock_entry({ conversation_id = 'conv-1', id = 'msg-2' }),
    create_mock_entry({ conversation_id = 'conv-2', id = 'msg-3' }),
  }

  local convs = HistMan.get_conversations(entries)
  MiniTest.expect.equality(type(convs), 'table')
  MiniTest.expect.equality(convs['conv-1'], 2)
  MiniTest.expect.equality(convs['conv-2'], 1)
end

T['get_conversations']['ignores empty conversation_ids'] = function()
  local entries = {
    create_mock_entry({ conversation_id = '', id = 'msg-1' }),
    create_mock_entry({ conversation_id = 'conv-1', id = 'msg-2' }),
  }

  local convs = HistMan.get_conversations(entries)
  MiniTest.expect.equality(convs[''], nil)
  MiniTest.expect.equality(convs['conv-1'], 1)
end

T['get_conversations']['handles empty entries list'] = function()
  local convs = HistMan.get_conversations({})
  MiniTest.expect.equality(type(convs), 'table')
  MiniTest.expect.equality(next(convs), nil)
end

return T
