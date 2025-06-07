---@module "sllm.utils"
local M = {}

--- Print all elements of `t`, each on its own line separated by "===".
---@param t string[] List of strings to print.
function M.print_table(t) print(table.concat(t, '\n===')) end

--- Check if a buffer handle is valid.
---@param buf integer? Buffer handle (or `nil`).
---@return boolean?
--   `true` if `buf` is non-`nil` and valid;
--   `false` if `buf` is non-`nil` but invalid;
--   `nil` if `buf == nil`.
function M.buf_is_valid(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

--- Return `true` if the current mode is any Visual mode (`v`, `V`, or Ctrl+V).
---@return boolean
function M.is_mode_visual()
  local current_mode = vim.api.nvim_get_mode().mode
  -- \22 is Ctrl-V
  return current_mode:match('^[vV\22]$') ~= nil
end

--- Get text of the current visual selection.
---@return string  The selected text (lines joined with "\n").
function M.get_visual_selection() return table.concat(vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.')), '\n') end

--- Get the filesystem path of a buffer, or `nil` if it has none.
---@param buf integer Buffer handle.
---@return string?  File path or `nil` if the buffer is unnamed.
function M.get_path_of_buffer(buf)
  local buf_name = vim.api.nvim_buf_get_name(buf)
  if buf_name == '' then
    return nil
  else
    return buf_name
  end
end

--- Convert an absolute path to one relative to the cwd.
---@param abspath string?  Absolute path (or `nil`).
---@return string?  Relative path if possible; otherwise original or `nil`.
function M.get_relpath(abspath)
  if abspath == nil then return abspath end
  local cwd = vim.uv.cwd()
  if cwd == nil then return abspath end
  local rel = vim.fs.relpath(cwd, abspath)
  if rel then
    return rel
  else
    return abspath
  end
end

--- Return the window ID showing buffer `buf`, or `nil` if not visible.
---@param buf integer Buffer handle.
---@return integer?  Window ID or `nil`.
function M.check_buffer_visible(buf)
  if not M.buf_is_valid(buf) then return nil end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then return win end
  end
  return nil
end

--- Simple template renderer: replaces `${key}` with `env[key]`.
---@param tmpl string             Template containing `${var}` placeholders.
---@param env table<string,string>  Lookup table for replacements.
---@return string  Rendered string.
function M.render(tmpl, env)
  -- wrap in () so we only return the substituted string (ignore count)
  return (tmpl:gsub('%${([%w_]+)}', env))
end

return M
