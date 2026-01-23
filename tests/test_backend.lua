local MiniTest = require('mini.test')
local LlmBackend = require('sllm.backend.llm')

local T = MiniTest.new_set({ name = 'backend' })

-- =============================================================================
-- LLM backend tests
-- =============================================================================

T['llm'] = MiniTest.new_set()

T['llm']['has correct name'] = function() MiniTest.expect.equality(LlmBackend.name, 'llm') end

T['llm']['get_templates_async is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.get_templates_async), 'function')
end

T['llm']['get_template_async is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.get_template_async), 'function')
end

T['llm']['get_templates_path is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.get_templates_path), 'function')
end

T['llm']['edit_template is a function'] = function()
  MiniTest.expect.equality(type(LlmBackend.edit_template), 'function')
end

T['llm']['get_command includes template flag'] = function()
  local cmd = LlmBackend.get_command({ cmd = 'llm' }, {
    prompt = 'test',
    template = 'my-template',
  })
  -- cmd is now a table of arguments
  MiniTest.expect.equality(type(cmd), 'table')
  MiniTest.expect.equality(vim.tbl_contains(cmd, '-t'), true)
  MiniTest.expect.equality(vim.tbl_contains(cmd, 'my-template'), true)
end

return T
