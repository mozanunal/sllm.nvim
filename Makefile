.PHONY: ci
ci: dev_install format-check lint test print_loc

.PHONY: dev_install
dev_install:
	@echo "------------------ dev_install ---------------------"
	brew install luacheck stylua tokei deno

.PHONY: format
format:
	@echo "------------------ format  -------------------------"
	stylua lua/ tests/
	deno fmt */*.md

.PHONY: format-check
format-check:
	@echo "------------------ format-check --------------------"
	stylua --check lua/ tests/
	deno fmt --check */*.md

.PHONY: lint
lint:
	@echo "------------------ lint  ---------------------------"
	luacheck lua/

.PHONY: test
test:
	@echo "------------------ unit_tests  ---------------------"
	nvim --headless -u scripts/minimal_init.lua \
     -c "lua MiniTest.run()" \
     -c "quit"

.PHONY: print_loc
print_loc:
	@echo "------------------ print_loc  ---------------------"
	@echo "--> whole project"
	@tokei
	@echo "--> lua folder"
	@tokei lua

.PHONY: gif
gif:
	@echo "------------------ make_gif  -----------------------"
	@vhs < ./assets/tapes/main.tape
	@open -R ./assets/workflow.gif

.PHONY: docs
docs:
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
