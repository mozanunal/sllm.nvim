-- Health check module for sllm.nvim
-- This module provides health checks for :checkhealth sllm

-- Module definition ==========================================================
local M = {}
local H = {}

-- Helper functionality =======================================================
H.check_nvim_version = function(health)
  local nvim_version = vim.version()
  if nvim_version.major == 0 and nvim_version.minor < 5 then
    health.warn('Neovim 0.5 or above is recommended for sllm.nvim.')
  else
    health.ok(string.format('Neovim version %d.%d.%d', nvim_version.major, nvim_version.minor, nvim_version.patch))
  end
end

H.check_llm_cli = function(health)
  local has_llm = vim.fn.executable('llm') == 1
  if not has_llm then
    health.error('llm CLI is required but not found in PATH', {
      'Install llm: https://github.com/simonw/llm',
      'Try: brew install llm  or  pip install llm',
    })
    return false
  else
    health.ok('llm CLI is installed')

    -- Try to get llm version
    local version_output = vim.fn.system('llm --version 2>&1')
    if vim.v.shell_error == 0 then health.info('Version: ' .. vim.trim(version_output)) end
    return true
  end
end

H.check_llm_models = function(health)
  -- Check if any models are installed
  local models_output = vim.fn.system('llm models 2>&1')
  if vim.v.shell_error ~= 0 then
    health.warn('Could not list llm models', {
      'Run: llm models',
    })
    return
  end

  local model_lines = vim.split(models_output, '\n', { plain = true, trimempty = true })
  local model_count = 0
  for _, line in ipairs(model_lines) do
    if line:match('^%d+:') then model_count = model_count + 1 end
  end

  if model_count > 0 then
    health.ok(string.format('Found %d llm model(s) available', model_count))
  else
    health.warn('No llm models found', {
      'Install a model plugin, e.g.:',
      '  llm install llm-openai',
      '  llm install llm-openrouter',
    })
  end
end

H.check_api_keys = function(health)
  -- Try to get default model to verify setup
  local default_model = vim.fn.system('llm models default 2>&1')
  if vim.v.shell_error == 0 and default_model ~= '' then
    health.ok('Default model configured: ' .. vim.trim(default_model))
  else
    health.info('No default model set', {
      'Set default model with: llm models default <model-name>',
      'Example: llm models default gpt-4o-mini',
    })
  end
end

H.check_optional_deps = function(health)
  -- Check for optional dependencies
  local has_mini_pick = pcall(require, 'mini.pick')
  local has_mini_notify = pcall(require, 'mini.notify')

  if has_mini_pick then
    health.ok('mini.pick is available (enhanced UI)')
  else
    health.info('mini.pick not found (optional)', {
      'Using vim.ui.select as fallback',
      'Install for better picker UI: https://github.com/echasnovski/mini.nvim',
    })
  end

  if has_mini_notify then
    health.ok('mini.notify is available (enhanced notifications)')
  else
    health.info('mini.notify not found (optional)', {
      'Using vim.notify as fallback',
      'Install for better notifications: https://github.com/echasnovski/mini.nvim',
    })
  end
end

-- Public API =================================================================
--- Health check function called by :checkhealth
M.check = function()
  local health = vim.health or require('health')

  health.start('sllm.nvim')

  -- Check Neovim version
  H.check_nvim_version(health)

  -- Check llm CLI
  local has_llm = H.check_llm_cli(health)

  -- Only check models and keys if llm is installed
  if has_llm then
    H.check_llm_models(health)
    H.check_api_keys(health)
  end

  -- Check optional dependencies
  H.check_optional_deps(health)
end

return M
