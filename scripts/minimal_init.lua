-- Quick-and-dirty editor tweaks

vim.g.mapleader = ' ' -- plugin may assume <leader>
vim.opt.swapfile = false -- no swapfiles in CI
vim.opt.backup = false
vim.opt.writebackup = false

-- Install package manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Minimal config
require('lazy').setup({
  { 'echasnovski/mini.nvim' },
})
require('mini.test').setup()

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
vim.opt.rtp:prepend(root)
