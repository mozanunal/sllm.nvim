local function refresh_sllm()
  m = dofile("lua/sllm/init.lua")
  m.setup()
end

vim.keymap.set("n", "<leader>rr", refresh_sllm, { desc = "Reload local sllm plugin" })
refresh_sllm()
