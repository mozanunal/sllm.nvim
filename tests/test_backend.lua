local MiniTest = require('mini.test')
local BackendRegistry = require('sllm.backend')
local Base = require('sllm.backend.base')
local LlmBackend = require('sllm.backend.llm')

local T = MiniTest.new_set({ name = 'backend' })

-- =============================================================================
-- Backend registry tests
-- =============================================================================

T['registry'] = MiniTest.new_set()

T['registry']['has llm backend registered by default'] = function()
  MiniTest.expect.equality(BackendRegistry.has('llm'), true)
end

T['registry']['get returns registered backend'] = function()
  local backend = BackendRegistry.get('llm')
  MiniTest.expect.no_error(function()
    assert(backend ~= nil)
    assert(backend.name == 'llm')
  end)
end

T['registry']['get returns nil for unknown backend'] = function()
  local backend = BackendRegistry.get('unknown_backend')
  MiniTest.expect.equality(backend, nil)
end

T['registry']['list returns all registered backends'] = function()
  local backends = BackendRegistry.list()
  MiniTest.expect.no_error(function()
    assert(type(backends) == 'table')
    assert(vim.tbl_contains(backends, 'llm'))
  end)
end

T['registry']['register adds new backend'] = function()
  local mock_backend = Base.extend({
    name = 'mock',
    get_models = function() return {} end,
    get_default_model = function() return 'mock-model' end,
    get_tools = function() return {} end,
    build_command = function() return 'mock-cmd' end,
  })
  BackendRegistry.register('mock', mock_backend)
  MiniTest.expect.equality(BackendRegistry.has('mock'), true)
  local backend = BackendRegistry.get('mock')
  MiniTest.expect.equality(backend.name, 'mock')
end

-- =============================================================================
-- Base backend tests
-- =============================================================================

T['base'] = MiniTest.new_set()

T['base']['extend creates backend with base methods'] = function()
  local custom = Base.extend({ name = 'custom' })
  MiniTest.expect.equality(custom.name, 'custom')
  MiniTest.expect.equality(type(custom.supports_streaming), 'function')
  MiniTest.expect.equality(type(custom.supports_tools), 'function')
end

T['base']['unimplemented methods throw errors'] = function()
  MiniTest.expect.error(function() Base.get_models({}) end)
  MiniTest.expect.error(function() Base.get_default_model({}) end)
  MiniTest.expect.error(function() Base.get_tools({}) end)
  MiniTest.expect.error(function() Base.build_command({}, {}) end)
end

T['base']['default supports_streaming returns false'] = function()
  MiniTest.expect.equality(Base.supports_streaming(), false)
end

T['base']['default supports_tools returns false'] = function() MiniTest.expect.equality(Base.supports_tools(), false) end

T['base']['default supports_history returns false'] = function()
  MiniTest.expect.equality(Base.supports_history(), false)
end

T['base']['default fetch_history returns nil'] = function() MiniTest.expect.equality(Base.fetch_history({}, {}), nil) end

T['base']['default fetch_conversation returns nil'] = function()
  MiniTest.expect.equality(Base.fetch_conversation({}, 'conv-id'), nil)
end

-- =============================================================================
-- LLM backend tests
-- =============================================================================

T['llm'] = MiniTest.new_set()

T['llm']['has correct name'] = function() MiniTest.expect.equality(LlmBackend.name, 'llm') end

T['llm']['supports_streaming returns true'] = function() MiniTest.expect.equality(LlmBackend.supports_streaming(), true) end

T['llm']['supports_tools returns true'] = function() MiniTest.expect.equality(LlmBackend.supports_tools(), true) end

T['llm']['build_command creates basic command'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, { prompt = 'hello' })
  MiniTest.expect.no_error(function()
    assert(cmd:find('llm') ~= nil)
    assert(cmd:find('hello') ~= nil)
  end)
end

T['llm']['build_command includes model flag'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    model = 'gpt-4',
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-m') ~= nil)
    assert(cmd:find('gpt%-4') ~= nil)
  end)
end

T['llm']['build_command includes system prompt'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    system_prompt = 'You are helpful',
  })
  MiniTest.expect.no_error(function() assert(cmd:find('-s') ~= nil) end)
end

T['llm']['build_command includes continue flag'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    continue = true,
  })
  MiniTest.expect.no_error(function() assert(cmd:find('-c') ~= nil) end)
end

T['llm']['build_command includes conversation id'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    continue = 'abc123',
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('--cid') ~= nil)
    assert(cmd:find('abc123') ~= nil)
  end)
end

T['llm']['build_command includes tools'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    tools = { 'tool1', 'tool2' },
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-T') ~= nil)
    assert(cmd:find('tool1') ~= nil)
    assert(cmd:find('tool2') ~= nil)
  end)
end

T['llm']['build_command includes model options'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    model_options = { temperature = 0.7 },
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-o') ~= nil)
    assert(cmd:find('temperature') ~= nil)
  end)
end

T['llm']['build_command uses custom cmd path'] = function()
  local cmd = LlmBackend.build_command({ cmd = '/usr/local/bin/llm' }, {
    prompt = 'test',
  })
  MiniTest.expect.no_error(function() assert(cmd:find('/usr/local/bin/llm') ~= nil) end)
end

T['llm']['build_command uses text flag for code files'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    ctx_files = { '/path/to/file.lua' },
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-f') ~= nil)
    assert(cmd:find('file.lua') ~= nil)
  end)
end

T['llm']['build_command uses attachment flag for images'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    ctx_files = { '/path/to/image.png' },
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-a') ~= nil)
    assert(cmd:find('image.png') ~= nil)
  end)
end

T['llm']['build_command uses attachment flag for pdf'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    ctx_files = { '/path/to/doc.pdf' },
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-a') ~= nil)
    assert(cmd:find('doc.pdf') ~= nil)
  end)
end

T['llm']['supports_history returns true'] = function() MiniTest.expect.equality(LlmBackend.supports_history(), true) end

T['llm']['fetch_history is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.fetch_history), 'function')
end

T['llm']['fetch_conversation is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.fetch_conversation), 'function')
end

return T
