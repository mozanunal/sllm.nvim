all: dev_install format lint unit_tests print_loc
precommit: all

dev_install:
	@echo "------------------ dev_install ---------------------"
	brew install luacheck stylua tokei

format:
	@echo "------------------ format  -------------------------"
	stylua lua/ tests/

format-check:
	@echo "------------------ format-check --------------------"
	stylua --check lua/ tests/

lint:
	@echo "------------------ lint  ---------------------------"
	luacheck lua/

unit_tests:
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

