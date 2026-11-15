# shellcheck shell=bash
# ==============================================================================
#  Bash customizations for Linux (from the dotfiles repo)
# ==============================================================================
#  Installed by Linux/install.sh as ~/.bashrc.d/dotfiles.sh and sourced from
#  ~/.bashrc. The distribution's own ~/.bashrc stays in place.
#
#  Contents
#    1. Interactive shells only
#    2. History
#    3. Prompt
#    4. Aliases
#    5. Completions
#    6. fzf
#    7. Local extras (~/.bashrc.local)
# ==============================================================================

# ------------------------------------------------------------------------------
#  1. Interactive shells only
# ------------------------------------------------------------------------------
# Scripts and scp sessions must not get prompts, aliases or completion output.

case $- in
  *i*) ;;
  *) return ;;
esac

# ------------------------------------------------------------------------------
#  2. History
# ------------------------------------------------------------------------------

HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups # skip duplicates and lines starting with a space
HISTTIMEFORMAT='%F %T  '
shopt -s histappend   # append to the history file, do not overwrite it
shopt -s checkwinsize # keep LINES and COLUMNS correct after a resize

# ------------------------------------------------------------------------------
#  3. Prompt
# ------------------------------------------------------------------------------
# [user@host] time directory branch#

# Print the current Git branch, or nothing outside a repository.
__dotfiles_git_branch() {
  git branch --show-current 2>/dev/null
}

PS1='\[\e[0m\][\[\e[0;1;38;5;253m\]\u\[\e[0;1;38;5;98m\]@\[\e[0;1;38;5;98m\]\H\[\e[0m\]] '
PS1+='\[\e[0;38;5;214m\]\t \[\e[0;1;38;5;75m\]\w '
PS1+='\[\e[0;38;5;34m\]$(__dotfiles_git_branch)\[\e[0;38;5;253m\]# \[\e[0m\]'

# ------------------------------------------------------------------------------
#  4. Aliases
# ------------------------------------------------------------------------------

# Ask before overwriting or deleting
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Short names
alias d='docker'
alias dco='docker-compose'
alias k='kubectl'
alias g='git'
alias h='history'
alias trf='terraform'

# ------------------------------------------------------------------------------
#  5. Completions
# ------------------------------------------------------------------------------
# Each block is skipped when the tool is not installed.

if command -v kubectl >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source <(kubectl completion bash)
  complete -o default -F __start_kubectl k
fi

if command -v terraform >/dev/null 2>&1; then
  complete -C "$(command -v terraform)" terraform trf
fi

# ------------------------------------------------------------------------------
#  6. fzf
# ------------------------------------------------------------------------------
# Ctrl+R searches the history, Ctrl+T picks files. Needs fzf 0.48 or newer.

if command -v fzf >/dev/null 2>&1 && fzf --bash >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

# ------------------------------------------------------------------------------
#  7. Local extras
# ------------------------------------------------------------------------------
# ~/.bashrc.local is yours: it is never installed or replaced. Use it for
# machine-only settings that should not be in a public repo.

if [[ -r ${HOME}/.bashrc.local ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.bashrc.local"
fi
