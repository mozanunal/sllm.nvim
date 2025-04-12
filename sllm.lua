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
		vim.api.nvim_set_option_value("bufhidden", "hide", { buf = M.llm_buf })
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = M.llm_buf })
	end
	return M.llm_buf
end

--- Show or focus the LLM buffer in a new split if it's not currently visible.
function M.show_llm_buffer()
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

function M.hide_llm_buffer()
  local win = find_llm_window()
  if win then
    -- Close the window displaying the LLM buffer.
    -- The second argument (`force`) is whether to abandon unsaved changes; 
    -- use `true` if you want to force-close without prompting.
    vim.api.nvim_win_close(win, false)
  end
end

--- Append lines to the LLM buffer.
--  This function inserts lines at the end of the buffer.
local function append_to_llm_buffer(lines)
	if lines then
		vim.api.nvim_buf_set_lines(M.llm_buf, -1, -1, false, lines)
	end
end

--- Prompt user for input, run `llm` asynchronously, and stream the output to the buffer.
function M.ask_llm()
	local continue = vim.fn.input("Continue previous chat? (y/N): "):lower() == "y"
	local user_input = vim.fn.input("Prompt: ")
	if user_input == "" then
		print("No prompt provided.")
		return
	end

	-- Show the buffer so we see the conversation happen
	M.show_llm_buffer()

	-- Build the command
	local cmd
	if continue then
		cmd = "llm -c " .. vim.fn.shellescape(user_input)
	else
		cmd = "llm " .. vim.fn.shellescape(user_input)
	end

	-- Add prompt to buffer
	append_to_llm_buffer({ "> " .. user_input, "" })

	-- Run the `llm` command asynchronously and stream output to the buffer.
	vim.fn.jobstart(cmd, {
		stdout_buffered = false, -- stream output immediately
		pty = true,
		on_stdout = function(_, data, _)
			if data then
				-- Append each non-empty line to the buffer
				for _, line in ipairs(data) do
					if line ~= "" then
						append_to_llm_buffer({ line })
					end
				end
				-- Scroll to the bottom in the LLM window, if visible
				local llm_win = find_llm_window()
				if llm_win then
					vim.api.nvim_set_current_win(llm_win)
					vim.cmd("normal! G")
				end
			end
		end,
		on_stderr = function(_, data, _)
			if data then
				-- Append stderr lines as well
				for _, line in ipairs(data) do
					if line ~= "" then
						append_to_llm_buffer({ line })
					end
				end
				local llm_win = find_llm_window()
				if llm_win then
					vim.api.nvim_set_current_win(llm_win)
					vim.cmd("normal! G")
				end
			end
		end,
		on_exit = function(_, exit_code, _)
			append_to_llm_buffer({ "", "Job finished with exit code: " .. exit_code })
			local llm_win = find_llm_window()
			if llm_win then
				vim.api.nvim_set_current_win(llm_win)
				vim.cmd("normal! G")
			end
		end,
	})
end

--- Setup function to create an :AskLLM user command.
function M.setup()
	vim.api.nvim_create_user_command(
		"AskLLM",
		function() M.ask_llm() end,
		{ desc = "Send a prompt to the llm CLI tool" }
	)
end

M.setup()
_G.Sllm = M
