local M = {}

M.buf_is_valid = function(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

M.is_mode_visual = function()
  local current_mode = vim.api.nvim_get_mode().mode
  return current_mode:match('^[vV]$') ~= nil
end

M.get_visual_selection = function()
  -- Check if there is a visual selection
  if M.is_mode_visual() then
    local _, ls, cs = unpack(vim.fn.getpos('v'))
    local _, le, ce = unpack(vim.fn.getpos('.'))
    return vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
  end
  return nil -- No selection
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
