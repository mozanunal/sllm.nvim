local function refresh_sllm()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  vim.opt.rtp:prepend(root)
  local m = dofile("lua/sllm/init.lua")
  m.setup({
    window_type   = "vertical",
    default_model = "default",
    -- function for item selection (like vim.ui.select)
    -- tested alternatives: vim.ui.select, require("mini.pick").ui_select, require("snacks.picker").select
    pick_func     = require("snacks.picker").select,
    -- function for notifications (like vim.notify)
    -- tested alternatives: vim.notify, require("mini.notify").make_notify(), require("snacks.notifier").notify
    notify_func   = require("snacks.notifier").notify,
  })
end

local function source_file()
  vim.cmd("source %")
end

vim.keymap.set("n", "<leader>rr", refresh_sllm, { desc = "Reload local sllm plugin" })
vim.keymap.set("n", "<leader>rx", source_file, { desc = "Source current file" })
refresh_sllm()
