-- tests/test_utils.lua
local MiniTest = require('mini.test')
local relpath = require('sllm.utils').get_relpath

-- (1) create the set, optionally give it a friendly name
local T = MiniTest.new_set({ name = 'utils.relpath' })

-- (2) attach tests to that set
T['returns abs-path when relative path cannot be resolved'] = function()
  MiniTest.expect.equality(relpath('/var/lib'), '/var/lib')
end

return T
