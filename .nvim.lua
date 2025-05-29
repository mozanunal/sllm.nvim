local function refresh_sllm()
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  vim.opt.rtp:prepend(root)
  local m = dofile("lua/sllm/init.lua")
  m.setup({ window_type = "vertical" })
end

local function source_file()
  vim.cmd("source %")
end

vim.keymap.set("n", "<leader>rr", refresh_sllm, { desc = "Reload local sllm plugin" })
vim.keymap.set("n", "<leader>rx", source_file, { desc = "Source current file" })
refresh_sllm()
