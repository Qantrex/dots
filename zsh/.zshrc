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
  tmux attach 2>/dev/null || tmux new-session
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

# Greeting - Runs only in interactive shells
if [[ $- == *i* ]]; then
  autoload -U colors && colors
  echo -n "${fg[red]}🌹 $USER${fg[magenta]}@bauarch ${reset_color}on ${fg[cyan]}"
  echo -n "$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')"
  echo -n "${reset_color} - uptime: ${fg[green]}"
  echo "$(uptime -p | sed 's/up //')"
fi

#
# -----------------------------------------------------------------------------
# PROMPT (Must be loaded at the end)
# -----------------------------------------------------------------------------
eval "$(starship init zsh)"
export PATH="$HOME/.local/bin:$PATH"
