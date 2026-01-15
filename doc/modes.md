# Modes and templates {#sllm-modes}

sllm.nvim treats `llm` templates as modes. The plugin ships with four defaults
that are symlinked into your `llm` template directory on setup:

- `sllm_chat` for general chat without tools.
- `sllm_read` for review/read-only operations.
- `sllm_agent` for tool-assisted, agentic workflows (bash/edit/write).
- `sllm_complete` for inline completion (`<leader><Tab>`).

## Switching modes

- Use the mode picker: `<leader>sM` or `/mode`.
- The current mode is shown in the winbar alongside the model.

## Customizing templates

Templates are standard `llm` YAML files. Common tasks:

- Edit an existing template: `llm templates edit sllm_agent`.
- Duplicate and modify: copy a shipped template to a new name under
  `~/.config/io.datasette.llm/templates/` and edit it.
- View contents: `llm templates show sllm_agent`.

Custom templates appear in the picker automatically and can be set as
`default_mode` in your config.
