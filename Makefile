ci: dev_install format-check lint test print_loc

dev_install:
	@echo "------------------ dev_install ---------------------"
	brew install luacheck stylua tokei deno

format:
	@echo "------------------ format  -------------------------"
	stylua lua/ tests/
	deno fmt *.md

format-check:
	@echo "------------------ format-check --------------------"
	stylua --check lua/ tests/
	deno fmt --check *.md

lint:
	@echo "------------------ lint  ---------------------------"
	luacheck lua/

test:
	@echo "------------------ unit_tests  ---------------------"
	nvim --headless -u scripts/minimal_init.lua \
     -c "lua MiniTest.run()" \
     -c "quit"

print_loc:
	@echo "------------------ print_loc  ---------------------"
	@echo "--> whole project"
	@tokei
	@echo "--> lua folder"
	@tokei lua

gif:
	@echo "------------------ make_gif  -----------------------"
	@vhs < ./assets/tapes/main.tape
	@open -R ./assets/workflow.gif
