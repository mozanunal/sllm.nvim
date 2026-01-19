local function clean_sllm()
 for k, _ in pairs(package.loaded) do
    if k:match("^sllm") then
      package.loaded[k] = nil
    end
  end
end


local function refresh_sllm()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  vim.opt.rtp:prepend(root)
  local m = dofile("lua/sllm/init.lua")
  m.setup({
    window_type   = "vertical",
    debug         = true,
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
