# Read by every zsh, also non-interactive ones (scripts, Claude Code's shell),
# so my own commands in ~/.local/bin are found there too. .zshrc adds the rest.
[[ :$PATH: == *:$HOME/.local/bin:* ]] || export PATH="$HOME/.local/bin:$PATH"
