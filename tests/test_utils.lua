local MiniTest = require('mini.test')
local Utils = require('sllm.utils')

local T = MiniTest.new_set({ name = 'utils' })

-- =============================================================================
-- get_relpath tests
-- =============================================================================

T['get_relpath'] = MiniTest.new_set()

T['get_relpath']['returns nil for nil input'] = function() MiniTest.expect.equality(Utils.get_relpath(nil), nil) end

T['get_relpath']['returns abs-path when relative path cannot be resolved'] = function()
  MiniTest.expect.equality(Utils.get_relpath('/var/lib'), '/var/lib')
end

T['get_relpath']['handles empty string'] = function()
  local result = Utils.get_relpath('')
  MiniTest.expect.equality(type(result), 'string')
end

-- =============================================================================
-- buf_is_valid tests
-- =============================================================================

T['buf_is_valid'] = MiniTest.new_set()

T['buf_is_valid']['returns nil for nil input'] = function() MiniTest.expect.equality(Utils.buf_is_valid(nil), false) end

T['buf_is_valid']['returns false for invalid buffer handle'] = function()
  MiniTest.expect.equality(Utils.buf_is_valid(999999), false)
end

T['buf_is_valid']['returns true for valid buffer'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  MiniTest.expect.equality(Utils.buf_is_valid(buf), true)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T['buf_is_valid']['returns false after buffer deletion'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(buf, { force = true })
  MiniTest.expect.equality(Utils.buf_is_valid(buf), false)
end

-- =============================================================================
-- is_mode_visual tests
-- =============================================================================

T['is_mode_visual'] = MiniTest.new_set()

T['is_mode_visual']['returns false in normal mode'] = function()
  vim.cmd('normal! \027') -- Escape to ensure normal mode
  MiniTest.expect.equality(Utils.is_mode_visual(), false)
end

-- =============================================================================
-- render tests
-- =============================================================================

T['render'] = MiniTest.new_set()

T['render']['replaces single variable'] = function()
  local result = Utils.render('Hello ${name}!', { name = 'World' })
  MiniTest.expect.equality(result, 'Hello World!')
end

T['render']['replaces multiple variables'] = function()
  local result = Utils.render('${greeting} ${name}!', { greeting = 'Hi', name = 'Ada' })
  MiniTest.expect.equality(result, 'Hi Ada!')
end

T['render']['leaves unmatched variables empty'] = function()
  local result = Utils.render('Hello ${name}!', {})
  MiniTest.expect.equality(result, 'Hello ${name}!')
end

T['render']['handles underscores in variable names'] = function()
  local result = Utils.render('${first_name} ${last_name}', { first_name = 'Ada', last_name = 'Lovelace' })
  MiniTest.expect.equality(result, 'Ada Lovelace')
end

T['render']['handles numeric variable names'] = function()
  local result = Utils.render('${var1} ${var2}', { var1 = 'one', var2 = 'two' })
  MiniTest.expect.equality(result, 'one two')
end

T['render']['preserves non-variable text'] = function()
  local result = Utils.render('No variables here', {})
  MiniTest.expect.equality(result, 'No variables here')
end

T['render']['handles empty template'] = function()
  local result = Utils.render('', { name = 'test' })
  MiniTest.expect.equality(result, '')
end

-- =============================================================================
-- extract_code_blocks tests
-- =============================================================================

T['extract_code_blocks'] = MiniTest.new_set()

T['extract_code_blocks']['extracts single code block'] = function()
  local lines = { '```lua', 'print("hello")', '```' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 1)
  MiniTest.expect.equality(blocks[1], 'print("hello")')
end

T['extract_code_blocks']['extracts multiple code blocks'] = function()
  local lines = {
    '```python',
    'print("first")',
    '```',
    'Some text',
    '```javascript',
    'console.log("second")',
    '```',
  }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 2)
  MiniTest.expect.equality(blocks[1], 'print("first")')
  MiniTest.expect.equality(blocks[2], 'console.log("second")')
end

T['extract_code_blocks']['handles empty code block'] = function()
  local lines = { '```', '```' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 0)
end

T['extract_code_blocks']['handles unclosed code block'] = function()
  local lines = { '```lua', 'print("unclosed")' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 1)
  MiniTest.expect.equality(blocks[1], 'print("unclosed")')
end

T['extract_code_blocks']['handles multi-line code block'] = function()
  local lines = {
    '```lua',
    'local x = 1',
    'local y = 2',
    'print(x + y)',
    '```',
  }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 1)
  MiniTest.expect.equality(blocks[1], 'local x = 1\nlocal y = 2\nprint(x + y)')
end

T['extract_code_blocks']['handles tilde fence'] = function()
  local lines = { '~~~', 'tilde content', '~~~' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 1)
  MiniTest.expect.equality(blocks[1], 'tilde content')
end

T['extract_code_blocks']['returns empty for no code blocks'] = function()
  local lines = { 'Just some text', 'No code here' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 0)
end

T['extract_code_blocks']['handles empty input'] = function()
  local blocks = Utils.extract_code_blocks({})
  MiniTest.expect.equality(#blocks, 0)
end

T['extract_code_blocks']['ignores language specifier'] = function()
  local lines = { '```python', 'x = 1', '```' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(blocks[1], 'x = 1')
end

T['extract_code_blocks']['handles code block with only whitespace'] = function()
  local lines = { '```', '   ', '```' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 1)
  MiniTest.expect.equality(blocks[1], '   ')
end

T['extract_code_blocks']['handles nested backticks in content'] = function()
  local lines = { '```markdown', 'Use `inline` code', '```' }
  local blocks = Utils.extract_code_blocks(lines)
  MiniTest.expect.equality(#blocks, 1)
  MiniTest.expect.equality(blocks[1], 'Use `inline` code')
end

-- =============================================================================
-- get_path_of_buffer tests
-- =============================================================================

T['get_path_of_buffer'] = MiniTest.new_set()

T['get_path_of_buffer']['returns nil for unnamed buffer'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  MiniTest.expect.equality(Utils.get_path_of_buffer(buf), nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- -- The buffer name gets resolved to the real path
-- T['get_path_of_buffer']['returns path for named buffer'] = function()
--   local buf = vim.api.nvim_create_buf(false, true)
--   local test_path = '/tmp/test_file.txt'
--   vim.api.nvim_buf_set_name(buf, test_path)
--   local result = Utils.get_path_of_buffer(buf)
--   -- On macOS, /tmp -> /private/tmp, so check the filename instead
--   MiniTest.expect.truthy(result ~= nil)
--   MiniTest.expect.truthy(result:match('test_file%.txt$'))
--   vim.api.nvim_buf_delete(buf, { force = true })
-- end

-- =============================================================================
-- check_buffer_visible tests
-- =============================================================================

T['check_buffer_visible'] = MiniTest.new_set()

T['check_buffer_visible']['returns nil for invalid buffer'] = function()
  MiniTest.expect.equality(Utils.check_buffer_visible(999999), nil)
end

T['check_buffer_visible']['returns nil for nil buffer'] = function()
  MiniTest.expect.equality(Utils.check_buffer_visible(nil), nil)
end

T['check_buffer_visible']['returns window id for visible buffer'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    width = 10,
    height = 10,
    row = 0,
    col = 0,
  })
  local result = Utils.check_buffer_visible(buf)
  MiniTest.expect.equality(result, win)
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T['check_buffer_visible']['returns nil for hidden buffer'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  MiniTest.expect.equality(Utils.check_buffer_visible(buf), nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
