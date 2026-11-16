#!/usr/bin/env bash
# ==============================================================================
#  install.sh (library) - helpers shared by MacOS/install.sh and Linux/install.sh
# ==============================================================================
#  Source this file after lib/ui.sh; do not execute it. Works with bash 3.2.
#
#  The calling script sets:
#    dry         true for --dry-run: report only, write nothing
#
#  Stages         begin  on_exit
#  Files          copy_file  seed_file  private_dir  save_backup  tempdir
#  Git identity   preserve_git_identity  ask_git_identity
#
#  Safety model
#    copy_file   managed file: skipped when identical, otherwise the old file is
#                copied to ~/.dotfiles-backup/<timestamp>/ before it is replaced
#    seed_file   starter file: created once, never replaced afterwards
# ==============================================================================

# ------------------------------------------------------------------------------
#  State
# ------------------------------------------------------------------------------

dry=${dry:-false}

backup=''         # backup directory, created on first replaced file
scratch=''        # temporary working directory, removed on exit
stage='startup'   # name of the running stage, reported if the script stops
count_new=0       # files that did not exist before
count_updated=0   # files replaced (old copy is in the backup)
count_unchanged=0 # files already identical
count_kept=0      # starter files that already exist and were left alone

# ------------------------------------------------------------------------------
#  Files: backup, copy, seed
# ------------------------------------------------------------------------------

# Runs on every exit: remove downloads and say where the script stopped.
on_exit() {
  local status=$?
  if [[ -n ${scratch} ]]; then rm -rf "${scratch}"; fi
  if ((status != 0 && status != 2)); then
    ui_fail "Stopped during: ${stage} (exit ${status})"
    if [[ -n ${backup} ]]; then ui_info "Replaced files are in $(ui_path "${backup}")"; fi
  fi
}

# begin <title> - start a numbered stage.
begin() {
  stage=$1
  ui_section "$1"
}

# Create the temporary download directory on first use.
tempdir() {
  if [[ -z ${scratch} ]]; then scratch=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXXXX"); fi
}

# Create the backup directory on first use.
ensure_backup() {
  local timestamp
  if [[ -z ${backup} ]]; then
    mkdir -p "${HOME}/.dotfiles-backup"
    timestamp=$(date +%Y%m%d-%H%M%S)
    backup=$(mktemp -d "${HOME}/.dotfiles-backup/${timestamp}.XXXXXXXX")
  fi
}

# save_backup <path> - copy an existing file into the backup directory,
# keeping its path relative to $HOME.
save_backup() {
  local path=$1 saved
  ensure_backup
  saved="${backup}/${path#"${HOME}"/}"
  mkdir -p "$(dirname "${saved}")"
  cp -pP "${path}" "${saved}"
}

# private_dir <path> - make sure a directory exists and only the user can
# read it (needed for ~/.ssh and the 1Password agent directory).
private_dir() {
  local dir=$1
  if [[ -d ${dir} ]] || "${dry}"; then return 0; fi
  mkdir -p "${dir}"
  chmod 700 "${dir}"
}

# copy_file <source> <destination> [<mode>] - install one managed file.
# Skips identical files, backs up a file before replacing it, and writes
# through a temporary file so a failed copy never leaves a half-written file.
copy_file() {
  local src=$1 dest=$2 mode=${3:-644} staged shown status note=''
  shown=$(ui_path "${dest}")
  if [[ ! -f ${src} ]]; then
    ui_fail "Missing source: ${src}"
    return 1
  fi
  if [[ -f ${dest} ]] && cmp -s "${src}" "${dest}"; then
    count_unchanged=$((count_unchanged + 1))
    ui_item skip unchanged "${shown}"
    return 0
  fi
  if [[ -d ${dest} ]]; then
    ui_fail "Expected a file at ${dest}"
    return 1
  fi
  if [[ -e ${dest} || -L ${dest} ]]; then
    status=updated
    note='backup kept'
    count_updated=$((count_updated + 1))
  else
    status=installed
    count_new=$((count_new + 1))
  fi
  if "${dry}"; then
    if [[ ${status} == updated ]]; then status='would update'; else status='would install'; fi
    ui_item ok "${status}" "${shown}"
    return 0
  fi
  if [[ ${status} == updated ]]; then save_backup "${dest}"; fi
  mkdir -p "$(dirname "${dest}")"
  staged=$(mktemp "${dest}.XXXXXXXX")
  if ! install -m "${mode}" "${src}" "${staged}" || ! mv -f "${staged}" "${dest}"; then
    rm -f "${staged}"
    ui_fail "Could not write ${dest}"
    return 1
  fi
  ui_item ok "${status}" "${shown}" "${note}"
}

# seed_file <source> <destination> [<mode>] - create a starter file once.
# Used for files that you edit by hand after the first install. An existing
# destination is left exactly as it is, whatever it contains.
seed_file() {
  local src=$1 dest=$2 mode=${3:-600}
  if [[ -e ${dest} || -L ${dest} ]]; then
    count_kept=$((count_kept + 1))
    ui_item skip kept "$(ui_path "${dest}")" 'yours, never replaced'
    return 0
  fi
  copy_file "${src}" "${dest}" "${mode}"
}

# ------------------------------------------------------------------------------
#  Git identity
# ------------------------------------------------------------------------------

# ask_git_identity <file> - ask for name and e-mail and store them in <file>.
# Only in an interactive terminal; a dry run or a piped run prints the command
# to set the identity by hand.
ask_git_identity() {
  local dest=$1 name='' email='' attempt
  local email_shape='^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  if "${dry}" || [[ ! -t 0 ]]; then
    ui_warn "No Git identity found. Set it with: git config --file ~/.gitconfig.local --edit"
    return 0
  fi
  ui_info "No Git identity found. It is stored in $(ui_path "${dest}"), not in the repo."
  name=$(ui_ask 'Your name for commits (user.name)')
  for attempt in 1 2 3; do
    email=$(ui_ask 'Your e-mail for commits (user.email)')
    if [[ ${email} =~ ${email_shape} ]]; then break; fi
    ui_info "That does not look like an e-mail address (attempt ${attempt} of 3)."
    email=''
  done
  if [[ -z ${name} || -z ${email} ]]; then
    ui_warn "Git identity not set. Set it with: git config --file ~/.gitconfig.local --edit"
    return 0
  fi
  tempdir
  if [[ -f ${dest} ]]; then cp "${dest}" "${scratch}/git.identity"; fi
  git config --file "${scratch}/git.identity" user.name "${name}"
  git config --file "${scratch}/git.identity" user.email "${email}"
  copy_file "${scratch}/git.identity" "${dest}" 600
}

# The managed ~/.gitconfig holds shared defaults only. Name, e-mail, signing
# and the commit template are device settings, so they are moved from the
# existing ~/.gitconfig into ~/.gitconfig.local, which the managed file includes.
# On a machine without an identity the installer asks for name and e-mail.
preserve_git_identity() {
  local key value kept=0 src="${HOME}/.gitconfig" dest="${HOME}/.gitconfig.local"
  begin 'Git identity'
  if [[ -f ${src} ]]; then
    for key in user.name user.email user.signingkey commit.gpgsign tag.gpgsign \
      gpg.format gpg.ssh.program commit.template; do
      value=$(git config --file "${src}" --get "${key}") || continue
      if git config --file "${dest}" --get "${key}" >/dev/null 2>&1; then continue; fi
      kept=$((kept + 1))
      if "${dry}"; then
        ui_item ok 'would keep' "${key}"
        continue
      fi
      tempdir
      if [[ ! -f ${scratch}/git.local && -f ${dest} ]]; then cp "${dest}" "${scratch}/git.local"; fi
      git config --file "${scratch}/git.local" "${key}" "${value}"
      ui_item ok kept "${key}"
    done
  fi
  if [[ -n ${scratch} && -f ${scratch}/git.local ]]; then copy_file "${scratch}/git.local" "${dest}" 600; fi
  if ((kept > 0)); then return 0; fi
  if git config --file "${dest}" --get user.email >/dev/null 2>&1; then
    ui_ok "Identity already in $(ui_path "${dest}")"
  else
    ask_git_identity "${dest}"
  fi
}
