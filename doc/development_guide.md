# Development guide {#sllm-development}

Use this guide when working on sllm.nvim itself.

## Quick workflow

- Install developer deps: `llm`, `stylua`, `luacheck`, `deno`, and `pandoc` (for
  docs).
- Run `make ci` before sending changes; it covers format, lint, tests, and docs.
- Faster loops: `make format`, `make lint`, `make test`, `make docs`.
- Regenerate help tags after docs: `:helptags doc`.

## Code conventions

- 2-space indent, single quotes, 120 character lines.
- Follow the Sllm + H pattern: public API on `Sllm.*`, helpers as `H.domain_*`.
- All mutable state lives in `H.state`; avoid module-level globals.
- Prefer small helpers over inline logic; keep names descriptive and snake_case.

## Adding features safely

- Extend `H.state` for new session data; thread config through `Sllm.setup`.
- Update `H.KEYMAP_DEFS` and `H.DEFAULT_CONFIG` when adding user-facing actions.
- Test public API flows (mini.test) rather than private helpers.
- Keep wrapper logic thin—delegate behavior to the `llm` CLI where possible.

## Documentation flow

- Author docs in doc/*.md; do not edit `doc/sllm.txt` directly.
- Cross-link guides from [doc/README.md](./README.md) and keep headings concise.

## Review checklist

- Are prompts, context resets, and template defaults covered in docs?
- Do new commands/keymaps appear in both code and docs?
- Did you handle canceled inputs and empty selections gracefully?
- Did you run the relevant `make` targets and skim for regressions?
