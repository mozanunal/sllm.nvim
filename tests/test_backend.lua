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
  MiniTest.expect.equality(type(custom.supports_tools), 'function')
end

T['base']['unimplemented methods throw errors'] = function()
  MiniTest.expect.error(function() Base.get_models({}) end)
  MiniTest.expect.error(function() Base.get_default_model({}) end)
  MiniTest.expect.error(function() Base.get_tools({}) end)
  MiniTest.expect.error(function() Base.build_command({}, {}) end)
end

T['base']['default supports_tools returns false'] = function() MiniTest.expect.equality(Base.supports_tools(), false) end

T['base']['default supports_history returns false'] = function()
  MiniTest.expect.equality(Base.supports_history(), false)
end

T['base']['default get_history returns nil'] = function() MiniTest.expect.equality(Base.get_history({}, {}), nil) end

T['base']['default get_session returns nil'] = function() MiniTest.expect.equality(Base.get_session({}, 'conv-id'), nil) end

T['base']['default supports_templates returns false'] = function()
  MiniTest.expect.equality(Base.supports_templates(), false)
end

T['base']['default get_templates returns empty table'] = function()
  local templates = Base.get_templates({})
  MiniTest.expect.equality(type(templates), 'table')
  MiniTest.expect.equality(#templates, 0)
end

T['base']['default get_template returns nil'] = function() MiniTest.expect.equality(Base.get_template({}, 'test'), nil) end

T['base']['default get_templates_path returns nil'] = function()
  MiniTest.expect.equality(Base.get_templates_path({}), nil)
end

T['base']['default edit_template returns false'] = function()
  MiniTest.expect.equality(Base.edit_template({}, 'test'), false)
end

-- =============================================================================
-- LLM backend tests
-- =============================================================================

T['llm'] = MiniTest.new_set()

T['llm']['has correct name'] = function() MiniTest.expect.equality(LlmBackend.name, 'llm') end

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

T['llm']['build_command includes online flag'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    online = true,
  })
  MiniTest.expect.no_error(function() assert(cmd:find('-o online 1') ~= nil) end)
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

T['llm']['get_history is a function'] = function() MiniTest.expect.equality(type(LlmBackend.get_history), 'function') end

T['llm']['get_session is a function'] = function() MiniTest.expect.equality(type(LlmBackend.get_session), 'function') end

T['llm']['supports_templates returns true'] = function() MiniTest.expect.equality(LlmBackend.supports_templates(), true) end

T['llm']['get_templates is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.get_templates), 'function')
end

T['llm']['get_template is a function'] = function() MiniTest.expect.equality(type(LlmBackend.get_template), 'function') end

T['llm']['get_templates_path is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.get_templates_path), 'function')
end

T['llm']['edit_template is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.edit_template), 'function')
end

T['llm']['build_command includes template flag'] = function()
  local cmd = LlmBackend.build_command({ cmd = 'llm' }, {
    prompt = 'test',
    template = 'my-template',
  })
  MiniTest.expect.no_error(function()
    assert(cmd:find('-t') ~= nil)
    assert(cmd:find('my%-template') ~= nil)
  end)
end

return T
