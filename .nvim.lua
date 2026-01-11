local function refresh_sllm()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  vim.opt.rtp:prepend(root)
  -- Clear module cache to force reload of all modules
  package.loaded['sllm'] = nil
  package.loaded['sllm.init'] = nil
  package.loaded['sllm.ui'] = nil
  package.loaded['sllm.job_manager'] = nil
  package.loaded['sllm.backend.llm'] = nil
  package.loaded['sllm.context_manager'] = nil
  package.loaded['sllm.history_manager'] = nil
  package.loaded['sllm.utils'] = nil
  package.loaded['sllm.health'] = nil

  -- Use require instead of dofile to get proper module loading
  local m = require("sllm")
  m.setup({
    window_type   = "vertical",
    show_usage = true,  -- Explicitly enable usage tracking
    pre_hooks = {
      -- {command='ls', add_to_context=true},
      -- {command='pwd', add_to_context=true},
      -- {command='cat %', add_to_context=true},
    }
    -- function for item selection (like vim.ui.select)
    -- tested alternatives: vim.ui.select, require("mini.pick").ui_select, require("snacks.picker").select
    -- pick_func     = require("snacks.picker").select,
    -- function for notifications (like vim.notify)
    -- tested alternatives: vim.notify, require("mini.notify").make_notify(), require("snacks.notifier").notify
    -- notify_func   = require("snacks.notifier").notify,
    -- input_func    = require("snacks.input").input,
  })
end

local function source_file()
  vim.cmd("source %")
end

vim.keymap.set("n", "<leader>rr", refresh_sllm, { desc = "Reload local sllm plugin" })
vim.keymap.set("n", "<leader>rx", source_file, { desc = "Source current file" })
refresh_sllm()
vim.notify("nvim.lua loaded!", vim.log.levels.INFO)
