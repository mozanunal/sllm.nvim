-- Script for generating help file using mini.doc
-- Run with: nvim --headless --noplugin -u scripts/minidoc.lua

-- Add current project to runtime path
vim.cmd([[set runtimepath=$VIMRUNTIME,$VIM/vimfiles,.,./after]])

-- Bootstrap mini.doc if not available
local minidoc_path = vim.fn.stdpath('data') .. '/site/pack/vendor/start/mini.nvim'
if not vim.loop.fs_stat(minidoc_path) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/echasnovski/mini.nvim',
    minidoc_path,
  })
end

-- Add mini.nvim to runtimepath
vim.cmd('set rtp+=' .. minidoc_path)

-- Setup mini.doc
local minidoc = require('mini.doc')
minidoc.setup({})

-- Generate documentation
-- Only include init.lua as it's the public API
local input_files = {
  'lua/sllm/init.lua',
}

local output_file = 'doc/sllm.txt'

-- Generate with custom hooks to match existing style
local doc = minidoc.generate(input_files, output_file, {
  hooks = {
    write_pre = function(lines)
      -- Remove any existing delimiter lines that might cause issues
      local filtered = {}
      for _, line in ipairs(lines) do
        if not line:match('^=====') and not line:match('^-----') then
          table.insert(filtered, line)
        end
      end
      return filtered
    end,
    write_post = function()
      print('Documentation generated at ' .. output_file)
      print('To view: :help sllm')
    end,
  },
})

-- Quit Neovim
vim.cmd('quitall!')
