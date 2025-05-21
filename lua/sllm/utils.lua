local M = {}

M.print_table = function(t)
  print(table.concat(t, "\n==="))
end

M.buf_is_valid = function(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

M.is_mode_visual = function()
  local current_mode = vim.api.nvim_get_mode().mode
  return current_mode:match('^[vV]$') ~= nil
end

M.get_visual_selection = function()
  return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos(".")), "\n")
end

M.get_path_of_buffer = function(buf)
  local buf_name = vim.api.nvim_buf_get_name(buf)
  if buf_name == '' then
    return nil -- no name associated with buffer
  else
    return buf_name
  end
end

M.get_relpath = function(abspath)
  if abspath == nil then return abspath end
  local cwd = vim.uv.cwd()
  if cwd == nil then return abspath end
  local relpath = vim.fs.relpath(cwd, abspath)
  if relpath then
    return relpath
  else
    return abspath
  end
end

M.check_buffer_visible = function(buf)
  if not M.buf_is_valid(buf) then return nil end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == buf then return w end
  end
  return nil
end

M.render = function(tmpl, env) return (tmpl:gsub('%${([%w_]+)}', env)) end

return M
