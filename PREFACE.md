## Preface & Philosophy of `sllm.nvim`

### The Story Behind `sllm.nvim`

The [`llm`](https://llm.datasette.io/en/stable/) command-line tool by Simon
Willison (creator of Django and Datasette) is a wonderfully extensible way to
interact with Large Language Models. Its power lies in its simplicity and vast
plugin ecosystem, allowing users to tap into numerous models directly from their
terminal.

Like many developers, I found myself frequently switching to web UIs like
ChatGPT, painstakingly copying and pasting code snippets, file contents, and
error messages to provide the necessary context for the AI. This interruption
broke my workflow and felt inefficient. I was particularly inspired by Simon's
explorations in using the `llm` tool for complex tasks, and it struck me how
beneficial it would be to manage and enrich this context seamlessly within
Neovim.

`sllm.nvim` was born out of the desire to streamline this process. It is a
simple plugin (~500 lines of Lua) that delegates the heavy lifting of LLM
interaction to the robust `llm` CLI. For its user interface, it leverages the
excellent utilities from `mini.nvim`. The core focus of `sllm.nvim` is to make
context gathering and LLM interaction a native part of the Neovim experience,
eliminating the need to ever leave the editor.

### The `sllm.nvim` Philosophy: A Focused Co-pilot

The Neovim ecosystem already has excellent, feature-rich plugins like
`CodeCompanion.nvim`, `avante.nvim`, `parrot.nvim`. So, why build another?
`sllm.nvim` isn't designed to be a replacement, but a focused alternative built
on a distinct philosophy and architecture.

Here are the key differentiators:

1. **On-the-fly Function Tools: A Game-Changer** This is the most significant
   differentiator. With `<leader>sF`, you can visually select a Python function
   in your buffer and **register it instantly as a tool for the LLM to use** in
   the current conversation. You don't need to pre-configure anything. This is a
   game-changer for interactive development:
   - **Ad-hoc Data Processing:** Have the LLM use your own function to parse a
     log file or reformat a data structure.
   - **Live Codebase Interaction:** Let the LLM use a function from your project
     to query a database or check an application's state.
   - **Ultimate Flexibility:** This workflow is impossible in a web UI and
     provides a level of dynamic integration that is unique to `sllm.nvim`.

2. **Radical Simplicity: It's a Wrapper, Not a Monolith** The fundamental
   difference is that `sllm.nvim` is a thin wrapper around the `llm` CLI. It
   doesn't reinvent the wheel by implementing its own API clients or
   conversation management. All heavy lifting is delegated to the `llm` tool,
   which is robust, battle-tested, and community-maintained. This keeps
   `sllm.nvim` itself incredibly lightweight, transparent, and easy to maintain.

3. **Instant Access to an Entire CLI Ecosystem** By building on `llm`, this
   plugin instantly inherits its vast and growing plugin ecosystem. This is a
   powerful advantage.
   - Want to access hundreds of models via OpenRouter? Just
     `llm install llm-openrouter`.
   - Need to feed a PDF manual or a GitHub repo into your context? There are
     `llm` plugins for that. This extensibility is managed at the `llm` level,
     allowing `sllm.nvim` to remain simple while giving you access to powerful
     workflows that other plugins would need to implement from scratch.

4. **Explicit Control: You Are the Co-pilot, Not the Passenger** Some tools aim
   to create an autonomous "agent" that tries to figure things out for you.
   `sllm.nvim` firmly believes in a **"co-pilot" model where you are always in
   control.** You explicitly provide context. You decide what the LLM sees: the
   current file (`<leader>sa`), diagnostics (`<leader>sd`), the output of a
   `git diff` (`<leader>sx`), or a new function tool (`<leader>sF`). The plugin
   won't guess your intentions, ensuring a predictable, reliable, and secure
   interaction every time.
