local MiniTest = require('mini.test')
local CtxMan = require('sllm.context_manager')

local T = MiniTest.new_set({ name = 'context_manager' })

-- =============================================================================
-- Context management tests
-- =============================================================================

T['context'] = MiniTest.new_set({
  hooks = {
    pre_case = function() CtxMan.reset() end,
  },
})

T['context']['reset clears all context'] = function()
  CtxMan.add_fragment('/path/to/file')
  CtxMan.add_tool('some_tool')
  CtxMan.add_function('def foo(): pass')
  CtxMan.add_snip('code', '/file.lua', 'lua')
  CtxMan.reset()
  local ctx = CtxMan.get()
  MiniTest.expect.equality(#ctx.fragments, 0)
  MiniTest.expect.equality(#ctx.tools, 0)
  MiniTest.expect.equality(#ctx.functions, 0)
  MiniTest.expect.equality(#ctx.snips, 0)
end

T['context']['add_fragment adds unique paths'] = function()
  CtxMan.add_fragment('/path/one')
  CtxMan.add_fragment('/path/two')
  CtxMan.add_fragment('/path/one') -- Duplicate
  local ctx = CtxMan.get()
  MiniTest.expect.equality(#ctx.fragments, 2)
end

T['context']['add_tool adds unique tools'] = function()
  CtxMan.add_tool('tool_a')
  CtxMan.add_tool('tool_b')
  CtxMan.add_tool('tool_a') -- Duplicate
  local ctx = CtxMan.get()
  MiniTest.expect.equality(#ctx.tools, 2)
end

T['context']['add_function adds unique functions'] = function()
  CtxMan.add_function('def foo(): pass')
  CtxMan.add_function('def bar(): pass')
  CtxMan.add_function('def foo(): pass') -- Duplicate
  local ctx = CtxMan.get()
  MiniTest.expect.equality(#ctx.functions, 2)
end

T['context']['add_snip stores snippet with metadata'] = function()
  CtxMan.add_snip('  local x = 1  ', '/test.lua', 'lua')
  local ctx = CtxMan.get()
  MiniTest.expect.equality(#ctx.snips, 1)
  MiniTest.expect.equality(ctx.snips[1].text, 'local x = 1') -- Trimmed
  MiniTest.expect.equality(ctx.snips[1].filepath, '/test.lua')
  MiniTest.expect.equality(ctx.snips[1].filetype, 'lua')
end

T['context']['add_snip allows duplicate snippets'] = function()
  CtxMan.add_snip('same code', '/file.lua', 'lua')
  CtxMan.add_snip('same code', '/file.lua', 'lua')
  local ctx = CtxMan.get()
  MiniTest.expect.equality(#ctx.snips, 2)
end

-- =============================================================================
-- render_prompt_ui tests
-- =============================================================================

T['render_prompt_ui'] = MiniTest.new_set({
  hooks = {
    pre_case = function() CtxMan.reset() end,
  },
})

T['render_prompt_ui']['returns trimmed user input when no context'] = function()
  local result = CtxMan.render_prompt_ui('Hello LLM')
  MiniTest.expect.equality(result, 'Hello LLM')
end

T['render_prompt_ui']['handles nil user input'] = function()
  local result = CtxMan.render_prompt_ui(nil)
  MiniTest.expect.equality(result, '')
end

T['render_prompt_ui']['includes fragments section'] = function()
  CtxMan.add_fragment('/absolute/path/file.lua')
  local result = CtxMan.render_prompt_ui('test')
  MiniTest.expect.equality(result:find('Fragments') ~= nil, true)
end

T['render_prompt_ui']['includes snippets section'] = function()
  CtxMan.add_snip('print("hello")', 'test.lua', 'lua')
  local result = CtxMan.render_prompt_ui('test')
  MiniTest.expect.equality(result:find('Snippets') ~= nil, true)
  MiniTest.expect.equality(result:find('```lua') ~= nil, true)
  MiniTest.expect.equality(result:find('print%("hello"%)') ~= nil, true)
end

T['render_prompt_ui']['includes both fragments and snippets'] = function()
  CtxMan.add_fragment('/path/to/file.py')
  CtxMan.add_snip('x = 1', 'test.py', 'python')
  local result = CtxMan.render_prompt_ui('my prompt')
  MiniTest.expect.equality(result:find('Fragments') ~= nil, true)
  MiniTest.expect.equality(result:find('Snippets') ~= nil, true)
  MiniTest.expect.equality(result:find('my prompt') ~= nil, true)
end

return T
