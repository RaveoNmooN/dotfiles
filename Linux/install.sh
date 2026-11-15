#!/usr/bin/env bash
# ==============================================================================
#  install.sh - install the Linux dotfiles from this checkout
# ==============================================================================
#
#  Usage
#    ./install.sh [--dry-run]
#
#  Options
#    --dry-run    Show what would change. Nothing is written.
#    -h, --help   Show this help.
#
#  Stages
#    1. Preflight      Bash and Git are present
#    2. Git identity   keep name, e-mail and signing in ~/.gitconfig.local;
#                      asks for name and e-mail when there is none
#    3. Files          .bashrc -> ~/.bashrc.d/dotfiles.sh
#                      .vimrc  -> ~/.vimrc
#                      .gitconfig -> ~/.gitconfig
#    4. Shell hook     make ~/.bashrc source ~/.bashrc.d/*.sh (added once)
#
#  Safety
#    Identical files are skipped. A file that would be replaced is first copied
#    to ~/.dotfiles-backup/<timestamp>/. The distribution's ~/.bashrc is kept:
#    only one small block is appended to it. No packages are installed.
#
#  Set NO_COLOR=1 for plain output.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
#  Settings
# ------------------------------------------------------------------------------

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bashrc="${HOME}/.bashrc"
bashrc_dir="${HOME}/.bashrc.d"

dry=false

# Shared helpers: terminal output, then file copy, backup and Git identity.
# shellcheck source=../lib/ui.sh
source "${repo}/../lib/ui.sh"
# shellcheck source=../lib/install.sh
source "${repo}/../lib/install.sh"

# ------------------------------------------------------------------------------
#  Arguments
# ------------------------------------------------------------------------------

usage() {
  echo 'Usage: install.sh [--dry-run]'
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run) dry=true ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

# ------------------------------------------------------------------------------
#  Stage 1 - Preflight
# ------------------------------------------------------------------------------

preflight() {
  begin 'Preflight'
  if [[ $(uname -s) != Linux ]]; then
    ui_warn "This installer is meant for Linux (found $(uname -s)). Use MacOS/install.sh on a Mac."
  else
    ui_ok "Linux $(uname -r) on $(uname -m)"
  fi
  if ! command -v git >/dev/null 2>&1; then
    ui_fail 'Git is missing. Install it with your package manager first.'
    return 1
  fi
  ui_ok "$(git --version)"
  if "${dry}"; then ui_info 'Dry run: nothing will be written.'; fi
}

# ------------------------------------------------------------------------------
#  Stage 3 - Files
# ------------------------------------------------------------------------------

install_files() {
  begin 'Files'
  copy_file "${repo}/.bashrc" "${bashrc_dir}/dotfiles.sh"
  copy_file "${repo}/.vimrc" "${HOME}/.vimrc"
  copy_file "${repo}/.gitconfig" "${HOME}/.gitconfig"
}

# ------------------------------------------------------------------------------
#  Stage 4 - Shell hook
# ------------------------------------------------------------------------------

# Fedora and RHEL source ~/.bashrc.d/* out of the box; Debian and Ubuntu do
# not. Append the loop once when ~/.bashrc does not mention the directory.
hook_bashrc() {
  begin 'Shell hook'
  if [[ -f ${bashrc} ]] && grep -q '\.bashrc\.d' "${bashrc}"; then
    ui_item skip unchanged "$(ui_path "${bashrc}")" 'already sources ~/.bashrc.d'
    return 0
  fi
  if "${dry}"; then
    ui_item ok 'would update' "$(ui_path "${bashrc}")" 'adds the ~/.bashrc.d loop'
    return 0
  fi
  if [[ -f ${bashrc} ]]; then save_backup "${bashrc}"; fi
  cat >>"${bashrc}" <<'HOOK'

# Load personal shell files (added by the dotfiles installer).
if [ -d "$HOME/.bashrc.d" ]; then
  for rc in "$HOME"/.bashrc.d/*.sh; do
    [ -r "$rc" ] && . "$rc"
  done
  unset rc
fi
HOOK
  ui_item ok updated "$(ui_path "${bashrc}")" 'backup kept'
}

# ------------------------------------------------------------------------------
#  Summary
# ------------------------------------------------------------------------------

summary() {
  local verb_new=installed verb_updated=updated
  if "${dry}"; then verb_new='to install' verb_updated='to update'; fi
  stage='summary'
  printf '\n'
  ui_rule
  printf '  %sDone in %s%s  %d %s, %d %s, %d unchanged' "${UI_BOLD}" "$(ui_elapsed)" "${UI_RESET}" \
    "${count_new}" "${verb_new}" "${count_updated}" "${verb_updated}" "${count_unchanged}"
  if ((UI_WARNINGS > 0)); then printf ', %s%d warning(s)%s' "${UI_YELLOW}" "${UI_WARNINGS}" "${UI_RESET}"; fi
  printf '\n'
  if [[ -n ${backup} ]]; then printf '  %-10s %s\n' 'Backup' "$(ui_path "${backup}")"; fi
  ui_rule
  ui_warnings_report

  printf '\n%sNext steps%s\n' "${UI_BOLD}" "${UI_RESET}"
  if "${dry}"; then
    ui_info 'Run again without --dry-run to apply.'
    return 0
  fi
  ui_info 'Open a new shell, or run: source ~/.bashrc'
  ui_info 'Machine-only shell settings go in ~/.bashrc.local (never replaced).'
}

# ------------------------------------------------------------------------------
#  Main
# ------------------------------------------------------------------------------

main() {
  local mode='install'
  parse_args "$@"
  trap on_exit EXIT

  if "${dry}"; then mode='dry run'; fi
  # shellcheck disable=SC2034 # read by ui_section in lib/ui.sh
  UI_TOTAL=4
  ui_banner 'dotfiles installer (Linux)' Mode "${mode}" Source "$(ui_path "${repo}")"

  preflight
  preserve_git_identity
  install_files
  hook_bashrc
  summary
}

main "$@"
