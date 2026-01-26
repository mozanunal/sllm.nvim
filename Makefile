.DEFAULT_GOAL := help

.PHONY: help ci dev_install format format_check lint test print_loc gif docs

help: ## Show this help
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

ci: dev_install format-check lint test print_loc ## Run all CI checks (dev_install, format-check, lint, test, print_loc)

dev_install: ## Install development dependencies (luacheck, stylua, tokei, deno)
	@echo "------------------ dev_install ---------------------"
	brew install luacheck stylua tokei deno

format: ## Format Lua and Markdown files
	@echo "------------------ format  -------------------------"
	stylua lua/ tests/
	deno fmt */*.md

format_check: ## Check formatting without modifying files
	@echo "------------------ format_check --------------------"
	stylua --check lua/ tests/
	deno fmt --check */*.md

lint: ## Lint Lua files with luacheck
	@echo "------------------ lint  ---------------------------"
	luacheck lua/

test: ## Run unit tests with MiniTest
	@echo "------------------ unit_tests  ---------------------"
	nvim --headless -u scripts/minimal_init.lua \
     -c "lua MiniTest.run()" \
     -c "quit"

print_loc: ## Print lines of code statistics
	@echo "------------------ print_loc  ---------------------"
	@echo "--> whole project"
	@tokei
	@echo "--> lua folder"
	@tokei lua

gif: ## Generate workflow GIF from VHS tape
	@echo "------------------ make_gif  -----------------------"
	@vhs < ./assets/tapes/main.tape
	@open -R ./assets/workflow.gif

docs: ## Generate vimdoc from markdown documentation
	@echo "------------------ docs  ---------------------------"
	pandoc --metadata=title="sllm.nvim" --columns=78 -t vimdoc \
		--lua-filter scripts/vimdoc_filter.lua \
		-o doc/sllm.txt \
		doc/README.md \
		doc/configure.md \
		doc/slash_commands.md \
		doc/modes.md \
		doc/hooks.md \
		doc/backend_llm.md \
		doc/api.md
	printf '\n vi''m:tw=78:ts=2:sw=2:et:ft=help:norl:\n' >> doc/sllm.txt
