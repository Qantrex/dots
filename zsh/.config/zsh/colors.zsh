# Monochrome colours for ls/eza, tab completion, zsh-syntax-highlighting, fzf, bat and less.
# Sourced near the end of .zshrc, after oh-my-zsh and the FZF block. White and greys, with
# Rosé Pine only for meaning: love for errors, gold for globs, iris for keywords.
export LS_COLORS="rs=0:fi=0:di=1;97:ln=3;37:ex=4;37:mh=0:pi=90:so=90:do=90:bd=90:cd=90:or=31:mi=31:su=1;31:sg=1;31:ca=0:tw=1;97:ow=1;97:st=1;97"
export EZA_COLORS="da=90:uu=37:un=37:gu=37:gn=37:sn=37:sb=90:ur=37:uw=37:ux=1;97:ue=1;97:gr=37:gw=37:gx=1;97:tr=37:tw=37:tx=1;97:xx=90:lc=90:hd=1;4;37"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#ffffff'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#ffffff'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#ffffff'
ZSH_HIGHLIGHT_STYLES[function]='fg=#ffffff'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#c4a7e7'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#eb6f92'
ZSH_HIGHLIGHT_STYLES[path]='fg=#e6e6e6,underline'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#b3b3b3'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#b3b3b3'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#f6c177'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#f6c177'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#808080'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#808080'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#808080,italic'
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#808080'

export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=bg:-1,bg+:#ffffff,fg:#b3b3b3,fg+:#000000,hl:#ffffff:underline,hl+:#000000:underline,info:#808080,prompt:#ffffff,pointer:#ffffff,marker:#c4a7e7,spinner:#808080,header:#808080,border:#2e2e2e,gutter:-1"
export BAT_THEME=ansi
export LESS_TERMCAP_so=$'\e[7m' LESS_TERMCAP_se=$'\e[27m'
