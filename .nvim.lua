-- .nvim.lua
-- Local dev helpers for the `sllm` plugin.
local function refresh_sllm()
  local this_file = debug.getinfo(1, "S").source:sub(2)
  local root = vim.fn.fnamemodify(this_file, ":h:h")

  -- Ensure local plugin is on runtimepath (useful when hacking on it in-place).
  vim.opt.rtp:prepend(root)

  -- Unload any previously loaded sllm modules to force a clean reload.
  for name in pairs(package.loaded) do
    if name:match("^sllm") then
      package.loaded[name] = nil
    end
  end

  local ok, mod = pcall(dofile, root .. "/lua/sllm/init.lua")
  if not ok then
    vim.notify("Failed to load sllm: " .. tostring(mod), vim.log.levels.ERROR)
    return
  end

  mod.setup({
    window_type = "vertical",
    debug = false,
    pre_hooks = {
      -- { command = "ls", add_to_context = true },
      -- { command = "pwd", add_to_context = true },
      -- { command = "cat %", add_to_context = true },
    },

    -- pick_func   = vim.ui.select,
    -- notify_func = vim.notify,
    -- input_func  = vim.ui.input,
  })
end

local function source_file()
  vim.cmd.source("%")
end

vim.keymap.set("n", "<leader>rr", refresh_sllm, { desc = "Reload local sllm plugin" })
vim.keymap.set("n", "<leader>rx", source_file, { desc = "Source current file" })

refresh_sllm()
vim.notify(".nvim.lua loaded!", vim.log.levels.INFO)
