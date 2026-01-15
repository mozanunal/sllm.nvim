# LLM backend setup {#sllm-backend}

sllm.nvim wraps the `llm` CLI. Set up the backend first, then use the plugin.

## Install llm

- Homebrew: `brew install llm`
- pipx: `pipx install llm`
- pip: `pip install llm`

Verify with `llm --help`.

## Install extensions

Install at least one provider plugin:

- `llm install llm-openrouter` for many models via OpenRouter.
- `llm install llm-anthropic` for Claude models.
- `llm install llm-openai` for OpenAI models.
- `llm install llm-gpt4all` for local models.

Browse more at https://llm.datasette.io/en/stable/plugins/directory.html.

## Set API keys

Use `llm keys set <provider>` (e.g., `llm keys set openrouter`) or environment
variables like `OPENAI_API_KEY`.

## Useful tool extensions

- `llm install llm-quickjs` for JavaScript tools.
- `llm install llm-shell` for shell execution (paired with agent mode).
- `llm install llm-curl` for HTTP fetch helpers.

Check each plugin's README for permissions and configuration.

## Configure sllm.nvim

In `setup()`, point to your llm binary if needed:
`backend_config = { cmd = '/full/path/to/llm' }`. The default uses `llm` from
`PATH`.

If the llm templates directory is non-standard, ensure your `llm` install is
reachable so the plugin can symlink its templates on setup.
