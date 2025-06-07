Output assets/workflow.mp4

### Global appearance
Set Shell "bash"
Set Width 1920
Set Height 1080
Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 18
Set Theme "Catppuccin Macchiato"
Set TypingSpeed 100ms
Set Framerate 24
Set CursorBlink false

### Launch Neovim (demo profile)
Sleep 300ms
Type "nvim" Enter
Sleep 300ms

Type " ss" Sleep 300ms
Type "Hi" Sleep 300ms Enter
Sleep 3000ms

Hide Type ":e ./lua/sllm/" Show
Type "job_manager.lua" Sleep 300ms Enter Sleep 300ms
Type " sa" Sleep 1000ms

Type " ss" Sleep 300ms
Type "Please review this file" Sleep 300ms Enter
Sleep 7000ms Hide Sleep 30000ms Show Sleep 1000ms

Type " sd" Sleep 1000ms
Type " ss" Sleep 300ms
Type "Check diagnostic messages fix this" Sleep 300ms Enter
Sleep 7000ms Hide Sleep 30000ms Show Sleep 1000ms

Type " su"
Set TypingSpeed 30ms
Type "https://neovim.io/doc/user/job_control.html" Sleep 300ms Enter
Set TypingSpeed 100ms
Sleep 1000ms

Type " ss" Sleep 300ms
Type "You can use the docs given" Sleep 300ms Enter
Sleep 7000ms Hide Sleep 30000ms Show Sleep 1000ms

Type " sm" Sleep 1000ms
Type "4o-mini" Sleep 300ms Enter Sleep 300ms
Type " ss" Sleep 300ms
Type " let's try it with thinking model, check this fix the warnings" Sleep 300ms Enter
Sleep 7000ms Hide Sleep 30000ms Show Sleep 1000ms


Type " sn" Sleep 1000ms
Type " sT" Sleep 1000ms
Type "quic" Sleep 300ms Enter Sleep 1000ms
Type " ss" Sleep 300ms
Type " Calculate 12+5x-12=98x+1231232 using tools" Sleep 300ms Enter
Sleep 7000ms Hide Sleep 30000ms Show Sleep 1000ms

Type " sn" Sleep 1000ms
Type ":e tools.py" Sleep 1000ms Enter Sleep 1000ms
Type " sF" Sleep 1000ms
Type " ss" Sleep 300ms
Type " Explore the steps in github CI using the tools, cat and ls (you can use 5 times max)" Sleep 300ms Enter
Sleep 7000ms Hide Sleep 30000ms Show Sleep 1000ms
Type ":qa!" Sleep 1000ms
