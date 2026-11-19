# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load.
# To use Starship, leave this blank.
ZSH_THEME=""

# List of plugins that have been enabled in Oh My Zsh
plugins=(
  git
  zoxide
  fzf
  history-substring-search
  zsh-autosuggestions
  zsh-completions
  zsh-you-should-use
  zsh-autopair
  zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# ~/.zshrc - auto-attach but don't leave orphan sessions
if [[ -z "$TMUX" ]]; then
  # By name: the side panel of the main Claude chat is its own grouped session ("panel").
  tmux attach -t main 2>/dev/null || tmux new-session -s main
fi

# -----------------------------------------------------------------------------
# USER CONFIGURATION (Your custom settings go here)
# -----------------------------------------------------------------------------

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Completion Caching
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path ~/.zsh/cache
zstyle ':completion:*' menu select # Enable the completion menu
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}" # Add colors to completions

# Options
setopt appendhistory
setopt sharehistory
setopt incappendhistory
setopt auto_pushd
setopt AUTO_CD # Auto cd without typing 'cd'
setopt hist_ignore_dups      # Ignore commands that are duplicates of the previous one
setopt hist_ignore_space     # Don't save commands that start with a space
setopt hist_find_no_dups     # When searching history, don't show duplicates

# Aliases
source ~/.zsh_aliases

# FZF: Add a preview window using bat for files and eza for directories
export FZF_DEFAULT_OPTS="--height 60% --layout=reverse --border \
--preview '([[ -d {} ]] && eza --tree --icons --color=always {}) | \
([[ -f {} ]] && bat --color=always --style=numbers --line-range=:500 {})' \
--bind 'ctrl-/:toggle-preview' --preview-window='right,60%,border-left'"

# Functions
fpath+=~/.config/zsh/functions
for func_file in ~/.config/zsh/functions/*(.); do
  autoload -U ${func_file:t}
done

# Environment & Path
export PATH="$HOME/.spicetify:$PATH"

# Custom Keybindings for word-wise movement
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^H' backward-delete-word

# The theme's colours (and any shell extras of the theme), before the greeting so
# a theme can change it: THEME_GREET_NAME replaces "you@host", and a theme_greet
# function adds to it.
source ~/.config/zsh/colors.zsh

# Greeting - Runs only in interactive shells
if [[ $- == *i* ]]; then
  autoload -U colors && colors
  echo -n "${fg[white]}${THEME_GREET_NAME:-$USER${reset_color}@bauarch}${reset_color} on "
  echo -n "$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')"
  echo -n " - uptime: "
  echo "$(uptime -p | sed 's/up //')"
  # Claude sessions left open by a shutdown or a closed terminal (see the cr function).
  open_claude=$(cr --count 2>/dev/null)
  (( open_claude > 0 )) && print -P "%F{244}${open_claude} Claude session(s) left open · cr reopens them%f"
  unset open_claude
  (( $+functions[theme_greet] )) && theme_greet
fi

#
# -----------------------------------------------------------------------------
# PROMPT (Must be loaded at the end)
# -----------------------------------------------------------------------------
eval "$(starship init zsh)"
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=micro VISUAL=micro
# systemd user ssh-agent.socket; ~/.ssh/config adds keys on first use (AddKeysToAgent)
[[ -z $SSH_AUTH_SOCK && -S $XDG_RUNTIME_DIR/ssh-agent.socket ]] && export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket
# Claude Code's shells (it snapshots this file): no aliases, so `ls`, `cat`, `grep` are the plain tools it
# expects. Functions and PATH stay.
[[ -n $CLAUDECODE ]] && unalias -a
