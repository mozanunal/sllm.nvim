-- File: lua/sllm/init.lua
local M = {}

-- We'll store the buffer handle in a module-level variable.
-- If it doesn't exist (or gets invalidated), we'll create a new one.
M.llm_buf = nil

local function buf_is_valid(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function find_llm_window()
	if not buf_is_valid(M.llm_buf) then
		return nil
	end
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(w) == M.llm_buf then
			return w
		end
	end
	return nil
end

local function get_llm_buffer()
	if not buf_is_valid(M.llm_buf) then
		-- Create new buffer
		M.llm_buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch buffer
		vim.api.nvim_set_option_value("bufhidden", "hide", { buf = M.llm_buf })
		vim.api.nvim_set_option_value("filetype", "markdown", { buf = M.llm_buf })
	end
	return M.llm_buf
end

local function append_to_llm_buffer(lines)
	if lines then
		vim.api.nvim_buf_set_lines(M.llm_buf, -1, -1, false, lines)
	end
end

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
		local new_win = vim.api.nvim_get_current_win()
		vim.wo[new_win].wrap = true
		vim.wo[new_win].linebreak = true
	end
end

-- Public function #1: focus the LLM window if it's open; otherwise show it.
function M.focus_llm_window()
	local llm_win = find_llm_window()
	if llm_win then
		vim.api.nvim_set_current_win(llm_win)
	else
		show_llm_buffer()
	end
end

-- Public function #2: toggle the LLM buffer’s visibility.
function M.toggle_llm_buffer()
	local llm_win = find_llm_window()
	if llm_win then
		vim.api.nvim_win_close(llm_win, false)
	else
		show_llm_buffer()
	end
end

-- Public function #3: prompt user for input, run `llm`, and stream output to the buffer.
function M.ask_llm()
	local continue = vim.fn.input("Continue previous chat? (y/N): "):lower() == "y"
	local user_input = vim.fn.input("Prompt: ")
	if user_input == "" then
		print("No prompt provided.")
		return
	end

	-- Show/focus the buffer so we see the conversation happen
	show_llm_buffer()

	-- Build the command
	local cmd = continue
			and ("llm -c " .. vim.fn.shellescape(user_input))
			or ("llm " .. vim.fn.shellescape(user_input))

	-- Add prompt to buffer
	append_to_llm_buffer({ "> " .. user_input, "" })

	-- Run `llm` asynchronously and stream output to the buffer.
	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		pty = true,
		on_stdout = function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						append_to_llm_buffer({ line })
					end
				end
			end
		end,
		on_stderr = function(_, data, _)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						append_to_llm_buffer({ line })
					end
				end
			end
		end,
		on_exit = function(_, exit_code, _)
			append_to_llm_buffer({ "", "Job finished with exit code: " .. exit_code })
		end,
	})
end

-- Public function #4: set up user commands and the keymaps you requested.
function M.setup()
	vim.keymap.set("n", "<leader>ss", M.ask_llm, { desc = "Ask LLM" })
	vim.keymap.set("n", "<leader>sa", M.ask_llm, { desc = "Add file to llm context" })
	vim.keymap.set("n", "<leader>sf", M.focus_llm_window, { desc = "Focus LLM window" })
	vim.keymap.set("n", "<leader>st", M.toggle_llm_buffer, { desc = "Toggle LLM buffer visibility" })
end

M.setup()
