#!/bin/zsh
# ShellCheck does not support Zsh. Check syntax with zsh -n.
# shellcheck disable=SC1071
# ==============================================================================
#  ~/.zprofile - login shell environment (managed by the dotfiles repo)
# ==============================================================================
#  Puts Homebrew on PATH and sets HOMEBREW_PREFIX. Apple Silicon installs to
#  /opt/homebrew, Intel to /usr/local.
# ==============================================================================

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
