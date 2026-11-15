#!/bin/zsh
# ShellCheck does not support Zsh. Check syntax with zsh -n.
# shellcheck disable=SC1071
# ==============================================================================
#  ~/.zshrc - interactive shell setup (managed by the dotfiles repo)
# ==============================================================================
#  Installed by install.sh. Edit the copy in the repo and run the installer
#  again; a direct edit here is replaced on the next run (a backup is kept).
#
#  Contents
#     1. Homebrew environment
#     2. Oh My Zsh
#     3. History
#     4. Aliases
#     5. Zsh plugins
#     6. Prompt (Oh My Posh)
#     7. fzf
#     8. Completions
#     9. Functions
#    10. Conda
#    11. PATH
#    12. Profile and local extras (~/.config/zsh/*.zsh)
#
#  Functions defined here
#    hrm       delete the last line of the shell history
#    ch        search the history with fzf and run the selection
#    fcd       cd into a directory picked with fzf
#    fgl       browse the Git log with a commit preview
#    fbranch   switch Git branch with fzf
#    fkctx     switch kubectl context with fzf
#    fkns      switch kubectl namespace with fzf
#    condaenv  activate a Conda environment picked with fzf
#    fkill     kill processes picked with fzf
#    bh        open pages from the Chrome history with fzf
# ==============================================================================

# ------------------------------------------------------------------------------
#  1. Homebrew environment
# ------------------------------------------------------------------------------
# ~/.zprofile sets it for login shells. Load it here for other shells.

[[ -n "$HOMEBREW_PREFIX" || ! -r "$HOME/.zprofile" ]] || source "$HOME/.zprofile"

# ------------------------------------------------------------------------------
#  2. Oh My Zsh
# ------------------------------------------------------------------------------

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

zstyle ':omz:update' mode auto
plugins=(git kubectl docker helm terraform aws)

# Vagrant ships its own Zsh completion. Add it before Oh My Zsh runs compinit.
for vagrant_completion in /opt/vagrant/embedded/gems/gems/vagrant-*/contrib/zsh(N/); do
  fpath=("$vagrant_completion" $fpath)
done
unset vagrant_completion

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# ------------------------------------------------------------------------------
#  3. History
# ------------------------------------------------------------------------------

HISTSIZE=500000
SAVEHIST=500000
setopt HIST_IGNORE_SPACE   # skip commands that start with a space
setopt HIST_REDUCE_BLANKS  # trim extra whitespace before saving

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
#  5. Zsh plugins
# ------------------------------------------------------------------------------
# Installed by the Brewfile. Syntax highlighting has to be loaded last.

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  plugin_file="$HOMEBREW_PREFIX/share/$plugin/$plugin.zsh"
  [[ ! -r "$plugin_file" ]] || source "$plugin_file"
done
unset plugin plugin_file

# ------------------------------------------------------------------------------
#  6. Prompt (Oh My Posh)
# ------------------------------------------------------------------------------
# Apple Terminal cannot render the theme, so it keeps the Oh My Zsh prompt.

if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]] && command -v oh-my-posh >/dev/null 2>&1; then
  if [[ -f "$HOME/.config/oh-my-posh/jandedobbeleer.omp.json" ]]; then
    eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/jandedobbeleer.omp.json")"
  else
    eval "$(oh-my-posh init zsh --config "$(brew --prefix oh-my-posh 2>/dev/null)/themes/jandedobbeleer.omp.json")"
  fi
fi

# ------------------------------------------------------------------------------
#  7. fzf
# ------------------------------------------------------------------------------
# Ctrl+T picks files with a preview, Ctrl+R searches the history.

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
  export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' --preview-window=right:60%"
  export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=up:3:wrap --sort"
fi

# ------------------------------------------------------------------------------
#  8. Completions
# ------------------------------------------------------------------------------
# HashiCorp tools complete themselves through bash-style completion.

(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }
autoload -U +X bashcompinit && bashcompinit
command -v terraform >/dev/null 2>&1 && complete -o nospace -C "$(command -v terraform)" terraform
command -v vault >/dev/null 2>&1 && complete -o nospace -C "$(command -v vault)" vault
command -v packer >/dev/null 2>&1 && complete -o nospace -C "$(command -v packer)" packer

# ------------------------------------------------------------------------------
#  9. Functions
# ------------------------------------------------------------------------------

# --- History ------------------------------------------------------------------

# hrm - delete the last line of the history file (for example a mistyped secret).
hrm() {
  ed -s "$HOME/.zsh_history" <<< $'-1,$d\nwq'
}

# ch - search the command history and run the selected command.
ch() {
  local selected
  selected=$( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//' )
  [[ -n "$selected" ]] && eval "$selected"
}

# --- Navigation ---------------------------------------------------------------

# fcd [dir] - cd into a directory below [dir] (default: current directory).
fcd() {
  local dir
  dir=$(find "${1:-.}" -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf +m) &&
    cd "$dir" || return
}

# --- Git ----------------------------------------------------------------------

# fgl - browse the Git log with a commit preview; prints the chosen hash.
fgl() {
  git log --oneline --decorate --color=always |
    fzf --ansi --preview 'git show --color=always {1}' --preview-window=right:60% |
    awk '{print $1}'
}

# fbranch - check out a local or remote branch picked with fzf.
fbranch() {
  local branch
  branch=$(git branch --all --color=always |
    grep -v HEAD |
    fzf --ansi --preview 'git log --oneline --color=always {1} | head -20' |
    sed 's/^[* ]*//' |
    sed 's|remotes/origin/||')
  [[ -n "$branch" ]] && git checkout "$branch"
}

# --- Kubernetes ---------------------------------------------------------------

# fkctx - switch the kubectl context.
fkctx() {
  local ctx
  ctx=$(kubectl config get-contexts -o name | fzf --preview 'kubectl config view --minify --context={}')
  [[ -n "$ctx" ]] && kubectl config use-context "$ctx"
}

# fkns - switch the namespace of the current kubectl context.
fkns() {
  local namespaces ns
  namespaces=$(kubectl get namespaces --no-headers -o custom-columns=':metadata.name' 2>&1)
  if [[ -z "$namespaces" ]]; then
    echo "No namespaces found. Check your kubectl context."
    return 1
  fi
  ns=$(echo "$namespaces" | fzf)
  [[ -n "$ns" ]] && kubectl config set-context --current --namespace="$ns"
}

# --- Conda --------------------------------------------------------------------

# condaenv - activate a Conda environment picked with fzf.
condaenv() {
  local env
  env=$(conda env list | grep -v '^#' | grep -v '^$' | awk '{print $1}' | fzf)
  [[ -n "$env" ]] && conda activate "$env"
}

# --- Processes ----------------------------------------------------------------

# fkill [signal] - kill the selected processes (default signal: 9).
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
  [[ -n "$pid" ]] && echo "$pid" | xargs kill -"${1:-9}"
}

# --- Browser ------------------------------------------------------------------

# bh - open pages from the Chrome history. Set CHROME_PROFILE to change the
# profile directory (default: "Profile 1").
bh() (
  local cols=$(( COLUMNS / 3 )) sep='{::}' dir
  dir=$(mktemp -d) || return 1
  trap 'command rm -rf "$dir"' EXIT
  command cp "$HOME/Library/Application Support/Google/Chrome/${CHROME_PROFILE:-Profile 1}/History" "$dir/history" || return 1
  sqlite3 -separator "$sep" "$dir/history" \
    "select substr(title, 1, $cols), url from urls order by last_visit_time desc" |
    awk -F "$sep" '{printf "%-'"$cols"'s  \x1b[36m%s\x1b[m\n", $1, $2}' |
    fzf --ansi --multi |
    sed 's#.*\(https*://\)#\1#' |
    while IFS= read -r url; do open "$url"; done
)

# ------------------------------------------------------------------------------
#  10. Conda
# ------------------------------------------------------------------------------
# Makes `conda activate` available without activating base. Looks in
# $CONDA_ROOT, the macOS package location and a user-local install.

for conda_root in "${CONDA_ROOT:-}" /opt/miniconda3 "$HOME/miniconda3"; do
  if [[ -n "$conda_root" && -r "$conda_root/etc/profile.d/conda.sh" ]]; then
    source "$conda_root/etc/profile.d/conda.sh"
    break
  fi
done
unset conda_root

# ------------------------------------------------------------------------------
#  11. PATH
# ------------------------------------------------------------------------------

typeset -U path  # keep entries unique
[[ ! -d /opt/kafka_2.13-3.9.1/bin ]] || path=(/opt/kafka_2.13-3.9.1/bin $path)
path=("$HOME/.local/bin" "$HOME/go/bin" $path)

# ------------------------------------------------------------------------------
#  12. Profile and local extras
# ------------------------------------------------------------------------------
# Every ~/.config/zsh/*.zsh file is sourced. The installer puts ec2.zsh
# there. local.zsh is yours: it is never installed or replaced, and it is
# sourced last so it can override anything above. Use it for machine-only
# settings such as AWS_PROFILE or the EC2_CONNECT_* variables.

for extra in "$HOME"/.config/zsh/*.zsh(N); do
  [[ "${extra:t}" == local.zsh ]] || source "$extra"
done
[[ ! -r "$HOME/.config/zsh/local.zsh" ]] || source "$HOME/.config/zsh/local.zsh"
unset extra
