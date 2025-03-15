local MiniTest = require('mini.test')
local render_template = require('sllm.context_manager').render_template

local T = MiniTest.new_set({ name = 'context_manager.render_template' })

T['replaces template variables with provided values (flat)'] = function()
  local template = 'Hello, ${name}! Your id is ${id}.'
  local vars = { name = 'Ada', id = 42 }
  MiniTest.expect.equality(render_template(template, vars), 'Hello, Ada! Your id is 42.')
end

T['replaces absent variables with nil string'] = function()
  local template = 'Goodbye, ${missing}!'
  MiniTest.expect.equality(render_template(template, {}), 'Goodbye, nil!')
end

return T
