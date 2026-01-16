# Slash commands {#sllm-slash}

Slash commands provide quick access to plugin features. Press `<leader>sx` to
open the command picker (fuzzy action picker), or type `/command` directly to
run one.

## Using slash commands

There are two ways to use slash commands:

1. **Picker**: Press `<leader>sx` to open the command picker (fuzzy action
   picker)
2. **Direct**: Type `/new` or `/model` to run a command immediately

## Chat commands

**`/new`** - Start a new chat session. Clears the buffer and resets the
conversation. Use this when you want to start fresh.

**`/history`** - Browse past conversations. Opens a picker showing your
conversation history (limited by `history_max_entries`). Select one to load it
into the buffer and continue from where you left off.

**`/cancel`** - Stop the current request. Use when a response is taking too long
or you want to interrupt the LLM.

## Context commands

Context commands let you add information for the LLM to reference. All context
commands use the `add-` prefix for clarity.

**`/add-file`** - Add the current buffer's file path to context. The LLM will be
able to read the file contents. Works with local files and URLs.

**`/add-url`** - Prompt for a URL and add it to context. Useful for referencing
documentation, issues, or web pages.

**`/add-selection`** - Add the current visual selection as a code snippet. The
snippet includes the file path and language for proper formatting.

**`/add-diagnostics`** - Add LSP diagnostics from the current buffer. Useful
when asking the LLM to help fix errors or warnings.

**`/add-output`** - Run a shell command and add its output to context. For
example, add `git diff` output or test results.

**`/add-tool`** - Add an installed llm tool to the session. Tools are provided
by llm extensions (like `llm-shell` or `llm-quickjs`).

**`/add-function`** - Add a Python function as a tool. In visual mode, adds the
selected code. In normal mode, adds the entire buffer. The function becomes
available for the LLM to call.

**`/clear-context`** - Reset all context. Clears files, snippets, tools, and
functions. Use this to start with a clean slate.

## Model commands

**`/model`** - Open the model picker. Shows all models available through your
llm installation.

**`/template`** - Pick a template/mode. Templates configure the LLM's system
prompt and available tools.

**`/online`** - Toggle online/web search mode. When enabled, the LLM can search
the web for current information.

**`/system`** - Set or update the system prompt. Enter a custom system prompt
that overrides the template's default.

## Options commands

**`/options`** - Show available options for the current model. Runs
`llm models --options` and displays the output.

**`/set-option`** - Set a model option. Prompts for a key and value, which are
passed to the model with `-o key value`.

**`/reset-options`** - Clear all model options set during the session.

## Template commands

**`/template-show`** - Show the active template's contents. Displays the YAML
configuration in the LLM buffer.

**`/template-edit`** - Open the active template file for editing. Opens the YAML
file in a new buffer so you can customize it.

## Copy commands

All copy commands use the `copy-` prefix for clarity.

**`/copy-code`** - Copy the last code block from the response. Extracts the most
recent fenced code block and copies to clipboard.

**`/copy-code-first`** - Copy the first code block from the response. Useful
when the first block is the one you need.

**`/copy-response`** - Copy the entire last response. Everything from the
response header to the end.

## UI commands

**`/focus`** - Focus the LLM window. Moves cursor to the chat buffer, creating
the window if needed.

**`/toggle`** - Toggle the LLM window. Opens it if closed, closes if open.

## Examples

**Quick workflow - ask about code:**

1. Select some code in visual mode
2. Press `<leader>ss` to open prompt
3. Type: "What does this do?"
4. The selection is automatically added to context

**Add multiple files then ask:**

1. Open first file, type `/add-file` (adds to context)
2. Open second file, type `/add-file` (adds to context)
3. Type your question about both files

**Debug with diagnostics:**

1. Open a file with errors
2. `/add-diagnostics` to add them to context
3. Ask: "How do I fix these errors?"

**Use git context:**

1. `/add-output` then enter `git diff`
2. Ask: "Write a commit message for these changes"

**Agent mode task:**

1. `/template` and select `sllm_agent`
2. Ask: "Find all TODO comments and list them"
3. The agent will use grep to search your codebase

## Notes

- Context is cleared after each prompt by default (see `reset_ctx_each_prompt`)
- The `/online` toggle is shown in the winbar when enabled
- Tools added with `/add-tool` require the corresponding llm extension installed
- Functions added with `/add-function` are Python code executed by llm
