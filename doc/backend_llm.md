# LLM backend setup {#sllm-backend}

sllm.nvim wraps Simon Willison's `llm` CLI. This guide covers installation,
provider setup, and troubleshooting.

## Installing llm

**macOS (Homebrew):**

```bash
brew install llm
```

**pipx (recommended for Python):**

```bash
pipx install llm
```

**pip:**

```bash
pip install llm
```

Verify the installation:

```bash
llm --version
llm --help
```

## Installing provider extensions

The llm CLI needs at least one provider extension. Install based on which models
you want to use:

**OpenRouter (many models, one API key):**

```bash
llm install llm-openrouter
llm keys set openrouter
# Paste your OpenRouter API key
```

**Anthropic (Claude models):**

```bash
llm install llm-anthropic
llm keys set anthropic
# Paste your Anthropic API key
```

**OpenAI:**

```bash
llm install llm-openai
llm keys set openai
# Paste your OpenAI API key
```

**Google (Gemini):**

```bash
llm install llm-gemini
llm keys set gemini
# Paste your Google AI API key
```

**Local models (Ollama):**

```bash
llm install llm-ollama
# No API key needed, just have Ollama running
```

**Local models (GPT4All):**

```bash
llm install llm-gpt4all
# No API key needed
```

Browse more extensions:
https://llm.datasette.io/en/stable/plugins/directory.html

## Setting the default model

After installing extensions, set your preferred default:

```bash
# List available models
llm models

# Set default
llm models default claude-3-5-sonnet
```

Or configure in sllm.nvim:

```lua
require('sllm').setup({
  default_model = 'claude-3-5-sonnet',
})
```

## Tool extensions

For agent mode (`sllm_agent`), the built-in Python functions handle most tasks.
You can also install llm tool extensions:

**Shell execution:**

```bash
llm install llm-shell
```

**JavaScript/QuickJS:**

```bash
llm install llm-quickjs
```

**HTTP requests:**

```bash
llm install llm-curl
```

**Web search:**

```bash
llm install llm-duckduckgo
```

Add tools to your session with `/tool` or the `tools` context.

## Configuring sllm.nvim

**Custom llm path:**

If llm isn't in your PATH, specify the full path:

```lua
require('sllm').setup({
  backend_config = {
    cmd = '/opt/homebrew/bin/llm',
  },
})
```

**Virtual environment:**

If llm is in a virtual environment:

```lua
require('sllm').setup({
  backend_config = {
    cmd = '/path/to/venv/bin/llm',
  },
})
```

## Verifying setup

Before using sllm.nvim, verify llm works:

```bash
# Check models are available
llm models

# Test a simple prompt
llm "Hello, world"

# Check templates directory
llm templates path
llm templates list
```

## Troubleshooting

### "llm: command not found"

The llm binary isn't in Neovim's PATH. Solutions:

1. Use full path in config:
   ```lua
   backend_config = { cmd = '/full/path/to/llm' }
   ```

2. Add to shell profile (`~/.zshrc` or `~/.bashrc`):
   ```bash
   export PATH="$PATH:/path/to/llm/bin"
   ```

3. For pipx installations:
   ```bash
   pipx ensurepath
   ```

### "No models found"

No provider extensions installed:

```bash
llm models  # Should show available models

# If empty, install an extension:
llm install llm-openrouter
llm keys set openrouter
```

### "API key not set"

The provider needs an API key:

```bash
# Check which key is needed
llm keys

# Set the key
llm keys set <provider>
```

Or use environment variables:

```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENROUTER_KEY="sk-or-..."
```

### Templates not appearing

The plugin symlinks templates on setup. Check:

```bash
# Verify templates directory exists and is writable
llm templates path
ls -la "$(llm templates path)"

# Should see sllm_* templates
llm templates list | grep sllm
```

If templates are missing, they'll be created on next `setup()` call.

### Slow responses

1. Check your internet connection
2. Try a different model (some are faster than others)
3. For local models, ensure sufficient RAM/GPU

### "Error: Model not found"

The specified model isn't available:

```bash
# List available models
llm models

# Check model name spelling
llm "test" -m exact-model-name
```

### Agent tools not working

For `sllm_agent` mode:

1. Check Python is available: `python3 --version`
2. Check required tools: `rg --version` (for grep fallback)
3. Check file permissions in your project

### History not loading

```bash
# Check logs database exists
llm logs path

# Verify logs are being stored
llm logs list -n 5
```

## Environment variables

Useful environment variables for llm:

```bash
# API keys
export OPENAI_API_KEY="..."
export ANTHROPIC_API_KEY="..."
export OPENROUTER_KEY="..."

# Disable telemetry (if using OpenAI)
export OPENAI_LOG=debug

# Custom config directory
export LLM_USER_PATH="~/.config/llm"
```

## Health check

Run Neovim's health check:

```vim
:checkhealth sllm
```

This verifies:

- llm binary is found
- At least one model is available
- Templates directory is accessible
