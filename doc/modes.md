# Modes and templates {#sllm-modes}

sllm.nvim uses llm templates as "modes" that configure the LLM's behavior.
Templates define system prompts and optionally provide Python functions as
tools.

## How templates work

Templates are YAML files stored in llm's templates directory. When you select a
template with `/template` or `<leader>sM`, it's passed to llm with the `-t`
flag.

The plugin ships with four default templates that are symlinked to your llm
templates directory on first setup.

## Shipped templates

### sllm_chat

General-purpose chat mode. Best for conversations, questions, and getting help
with code.

System prompt:

```
You are a sllm plugin living within neovim.
Always answer with markdown.
If the offered change is small, return only the changed part or function,
not the entire file.
```

Use cases:

- Ask questions about code
- Get explanations
- Discuss architecture
- General conversation

### sllm_read

Code review mode with read-only file access. The LLM can explore your codebase
but cannot make changes.

Available tools:

- `list(path)` - List directory contents
- `read(path, start_line, end_line)` - Read file contents
- `head(path, lines)` - Quick preview of file's first N lines
- `grep(pattern, path, file_pattern)` - Search with regex
- `glob(pattern)` - Find files by pattern

Use cases:

- Code review
- Understanding unfamiliar code
- Finding patterns in the codebase
- Security analysis

### sllm_agent

Full agentic mode with read and write access. The LLM can execute commands, read
files, and make changes.

Available tools:

- `bash(command)` - Execute shell commands
- `read(path, start_line, end_line)` - Read file contents
- `head(path, lines)` - Quick preview of file's first N lines
- `write(path, content)` - Create or overwrite files
- `edit(path, old_str, new_str)` - Replace exact strings in files
- `grep(pattern, path, file_pattern)` - Search with regex
- `glob(pattern)` - Find files by pattern
- `list(path)` - List directory contents
- `patch(content)` - Apply unified diff patches
- `webfetch(url)` - Fetch content from URLs

Use cases:

- Implement features end-to-end
- Refactor code across files
- Run tests and fix failures
- Automate repetitive tasks

**Warning**: Agent mode can modify files. Review changes before committing.

**Note**: Default mode is `sllm_chat`; switch with `<leader>sM` or `/template`.

### sllm_complete

Inline completion mode. Used internally by `<leader><Tab>` / `complete_code()`
for code completion at the cursor. Uses the `sllm_complete` template to send the
buffer-around-cursor context (no markdown; raw code out) and runs synchronously
for clean insertion.

System prompt:

```
Complete the code at the cursor position.
Output ONLY the completion code, no explanations or markdown.
Match the existing code style and indentation.
```

This mode outputs raw code without markdown formatting, suitable for direct
insertion into your buffer.

## Switching modes

**During a session:**

- Press `<leader>sM` or type `/template` at the prompt
- Select from the picker

**At startup:**

```lua
require('sllm').setup({
  default_mode = 'sllm_agent',  -- or any template name
})
```

**Temporarily clear mode:**

```lua
require('sllm').setup({
  default_mode = nil,  -- no template, uses model's default behavior
})
```

## Creating custom templates

### Step 1: Create the template file

Templates live in llm's templates directory. Find it with:

```bash
llm templates path
```

Typically: `~/.config/io.datasette.llm/templates/`

Create a new YAML file:

```yaml
# ~/.config/io.datasette.llm/templates/my_template.yaml
system: |
  You are a helpful coding assistant.
  Always explain your reasoning.
  Use the project's existing code style.
```

### Step 2: Add tools (optional)

Add Python functions that the LLM can call:

```yaml
system: |
  You are a code reviewer. Use your tools to analyze code.
functions: |
  import subprocess
  from pathlib import Path

  def run_tests(test_path: str = ".") -> str:
    """Run tests and return results.

    Args:
        test_path: Path to test file or directory
    """
    result = subprocess.run(
      ["pytest", test_path, "-v"],
      capture_output=True,
      text=True,
      cwd=Path.cwd()
    )
    return result.stdout + result.stderr
```

### Step 3: Use your template

Your template appears in the mode picker immediately:

```
<leader>sM -> select "my_template"
```

Or set as default:

```lua
require('sllm').setup({
  default_mode = 'my_template',
})
```

## Template examples

### Commit message writer

```yaml
# commit_writer.yaml
system: |
  You are a git commit message writer.
  Given a diff, write a conventional commit message.
  Format: type(scope): description

  Types: feat, fix, docs, style, refactor, test, chore
  Keep the first line under 72 characters.
  Add a body if the change is complex.
```

### Documentation generator

```yaml
# doc_generator.yaml
system: |
  You are a documentation writer.
  Generate clear, concise documentation.
  Use the project's existing documentation style.
  Include examples where helpful.
functions: |
  from pathlib import Path

  def read_file(path: str) -> str:
    """Read a file's contents."""
    return Path(path).read_text()

  def list_files(pattern: str = "**/*.lua") -> str:
    """List files matching a pattern."""
    files = Path.cwd().glob(pattern)
    return "\n".join(str(f) for f in files)
```

### Test writer

```yaml
# test_writer.yaml
system: |
  You are a test writer.
  Write comprehensive tests for the given code.
  Follow the project's existing test patterns.
  Include edge cases and error conditions.
functions: |
  import subprocess
  from pathlib import Path

  def read_file(path: str) -> str:
    """Read a file to understand what to test."""
    return Path(path).read_text()

  def run_tests() -> str:
    """Run existing tests to see patterns."""
    result = subprocess.run(
      ["make", "test"],
      capture_output=True,
      text=True,
      cwd=Path.cwd()
    )
    return result.stdout + result.stderr
```

## Managing templates

**List templates:**

```bash
llm templates list
```

**Show template content:**

```bash
llm templates show sllm_agent
```

**Edit template:**

```bash
llm templates edit sllm_agent
```

Or use `/template-edit` in sllm.nvim when the template is active.

## Tips

- Start with `sllm_chat` for simple questions
- Use `sllm_read` when you want the LLM to explore without changing anything
- Use `sllm_agent` for tasks that require file changes
- Keep custom templates focused on specific tasks
- Test functions locally before adding them to templates
- Use docstrings in functions - the LLM reads them to understand the tool
