-- File: lua/sllm/init.lua
local M = {}

-- We'll store the buffer handle in a module-level variable.
-- If it doesn't exist (or gets invalidated), we'll create a new one.
M.llm_buf = nil

--- Return true if the buffer still exists and is valid.
local function buf_is_valid(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

--- Find a window that is currently displaying the llm buffer.
--- Returns nil if no window is showing it.
local function find_llm_window()
	if not buf_is_valid(M.llm_buf) then
		return nil
	end
	local wins = vim.api.nvim_list_wins()
	for _, w in ipairs(wins) do
		if vim.api.nvim_win_get_buf(w) == M.llm_buf then
			return w
		end
	end
	return nil
end

--- Create or reuse the LLM buffer, set some buffer-local options, etc.
local function get_llm_buffer()
	if not buf_is_valid(M.llm_buf) then
		-- Create new buffer
		M.llm_buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch buffer
		-- Set some (non-deprecated) buffer-local options
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = M.llm_buf })
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = M.llm_buf })
	end
	return M.llm_buf
end

--- Show or focus the LLM buffer in a new split if it's not currently visible.
local function show_llm_buffer()
	local buf = get_llm_buffer()
	local win = find_llm_window()
	if win then
		-- Already visible, just jump there
		vim.api.nvim_set_current_win(win)
	else
		-- Not visible anywhere, so open in a new split
		vim.cmd("vsplit")
		vim.api.nvim_win_set_buf(0, buf)
		local win = vim.api.nvim_get_current_win()
		vim.wo[win].wrap = true
		vim.wo[win].linebreak = true
	end
end

--- Append lines to the LLM buffer.
--  This function inserts lines at the end of the buffer.
local function append_to_llm_buffer(lines)
	local buf = get_llm_buffer()
	local line_count = vim.api.nvim_buf_line_count(buf)
	-- Insert lines at the end (range: [line_count, line_count])
	vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
end

--- Prompt user for input, run `llm`, and append the conversation to a single buffer.
function M.ask_llm()
	local continue = vim.fn.input("Continue previous chat? (y/N): "):lower() == "y"
	local user_input = vim.fn.input("Prompt: ")
	if user_input == "" then
		print("No prompt provided.")
		return
	end

	-- Show the buffer so we see the conversation happen
	show_llm_buffer()

	-- Build the command
	-- Default: "llm <prompt>"
	-- If the user wants to continue: "llm -c <prompt>"
	local cmd
	if continue then
		cmd = "llm -c " .. vim.fn.shellescape(user_input)
	else
		cmd = "llm " .. vim.fn.shellescape(user_input)
	end

	local output = vim.fn.system(cmd)
	local llm_win = find_llm_window()
	-- Add ">>> " prefix for the user's prompt
	append_to_llm_buffer({ "> " .. user_input .. "\r\n" })

	-- Run the `llm` CLI
	local cmd = "llm " .. vim.fn.shellescape(user_input)
	local output = vim.fn.system(cmd)

	-- Split the output into lines, append them to the buffer
	local lines = {}
	for line in output:gmatch("[^\r\n]+") do
		-- table.insert(lines, line)
		append_to_llm_buffer({ line })
	end

	-- append_to_llm_buffer(lines)
	-- Optionally scroll to the bottom (make sure we’re in that window)
	if llm_win then
		vim.api.nvim_set_current_win(llm_win)
		vim.cmd("normal! G") -- jump to end of buffer
	end
end

--- Setup function to create an :AskLLM user command.
function M.setup()
	vim.api.nvim_create_user_command(
		"AskLLM",
		function() M.ask_llm() end,
		{ desc = "Send a prompt to the llm CLI tool" }
	)
	vim.api.nvim_create_user_command(
		"LLMTerm",
		function() M.open_llm_terminal() end,
		{ desc = "Open a vertical split terminal running llm" }
	)
end

return M
