# Slash commands {#sllm-slash}

Type `/` at the prompt to open the command picker, or type `/command` directly
to run one. Commands are grouped by purpose.

## Chat

- `/new` starts a new chat and clears the buffer.
- `/history` opens the conversation picker (uses `history_max_entries`).
- `/cancel` stops the current request.

## Context

- `/file` adds the current buffer path to context.
- `/url` prompts for a URL and adds its content.
- `/selection` adds the current visual selection.
- `/diagnostics` adds the current buffer diagnostics.
- `/command` runs a shell command and adds its output.
- `/tool` adds an installed llm tool.
- `/function` adds a Python function as a tool.
- `/clear` clears all context (files, snippets, tools, functions).

## Model and modes

- `/model` picks a model.
- `/mode` picks a template/mode.
- `/online` toggles online/web mode.
- `/options` shows `llm models --options` for the active model.
- `/system` sets the system prompt.
- `/option` sets a model option key/value.
- `/reset-options` clears all model options.

## Templates

- `/template` shows the active template contents in a buffer.
- `/edit` opens the active template for editing.

## Copy and UI

- `/code` copies the last code block from the response buffer.
- `/code-first` copies the first code block.
- `/response` copies the last response.
- `/focus` focuses the LLM window.
- `/toggle` toggles the LLM window.
