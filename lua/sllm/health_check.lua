local M = {}

M.check = function()
  -- Use the `vim.health` API provided by Neovim
  local health = require('vim.health')

  -- 1. Check for Neovim version
  local nvim_version = vim.version()
  if (nvim_version.major < 0) or (nvim_version.minor < 5) then
    health.warn('Neovim 0.5 or above is recommended for myplugin.')
  else
    health.ok('Neovim version is 0.5 or above.')
  end

  -- 2. Check if a required dependency exists
  local has_required_dep = vim.fn.executable('llm') == 1
  if not has_required_dep then
    health.error('llm is required by myplugin but not found in your PATH.')
  else
    health.ok('llm is installed and found in your PATH.')
  end
end

return M
