#!/usr/bin/env bash
# ==============================================================================
#  install.sh - set up or restore a Mac from this dotfiles checkout
# ==============================================================================
#
#  Usage
#    ./install.sh [--dry-run] [--files-only]
#
#  Options
#    --dry-run         Show what would change. Nothing is written or installed.
#    --files-only      Only copy the managed files. No Homebrew, vendor
#                      packages or fonts.
#    -h, --help        Show this help.
#
#  Stages
#    1. Preflight        macOS, architecture, Command Line Tools
#    2. Homebrew         Homebrew, Brewfile packages, Oh My Zsh
#    3. Vendor packages  AWS CLI v2 and Miniconda (signed installers)
#    4. Fonts            Hack Nerd Font 3.2.1, checksum verified
#    5. Git identity     keep name, e-mail and signing in ~/.gitconfig.local
#    6. Managed files    shell, Git, iTerm2, prompt, EC2 helpers, keyboard swap,
#                        and the SSH and 1Password agent starter files
#    7. Checks           placeholders and public keys of ~/.ssh/config
#
#  Safety
#    Identical files are skipped. A file that would be replaced is first copied
#    to ~/.dotfiles-backup/<timestamp>/. Stages 2-4 are skipped by --files-only.
#
#    ~/.ssh/config and the 1Password agent.toml are seeded from the .example
#    files only when they do not exist. An existing file is never replaced,
#    because it holds your own hosts and keys.
#
#  Works with the stock macOS bash 3.2. Set NO_COLOR=1 for plain output.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
#  Settings
# ------------------------------------------------------------------------------

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
zsh_dir="${HOME}/.config/zsh" # extra shell files sourced by ~/.zshrc
bin_dir="${HOME}/.local/bin"  # user executables, on PATH through ~/.zshrc
ssh_config="${HOME}/.ssh/config"
agent_config="${HOME}/.config/1Password/ssh/agent.toml"
iterm_app=${DOTFILES_ITERM_APP:-/Applications/iTerm.app}      # overridable for tests
iterm_domain=${DOTFILES_ITERM_DOMAIN:-com.googlecode.iterm2} # overridable for tests

seeded_ssh=false   # true when ~/.ssh/config was created from the starter in this run
seeded_agent=false # same for the 1Password agent.toml
keys_open=0        # IdentityFile lines that still need a public key file

keyboard_label='com.dotfiles.keyboard-remap' # LaunchAgent that reapplies the key swap
karabiner_app=${DOTFILES_KARABINER_APP:-/Applications/Karabiner-Elements.app} # overridable for tests
skip_launchctl=${DOTFILES_SKIP_LAUNCHCTL:-false} # true: install the agent file but do not load it (tests)

dry=false
files_only=false

# Shared helpers: terminal output, then file copy, backup and Git identity.
# shellcheck source=../lib/ui.sh
source "${repo}/../lib/ui.sh"
# shellcheck source=../lib/install.sh
source "${repo}/../lib/install.sh"

# ------------------------------------------------------------------------------
#  Arguments
# ------------------------------------------------------------------------------

usage() {
  echo 'Usage: install.sh [--dry-run] [--files-only]'
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run) dry=true ;;
      --files-only) files_only=true ;;
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
  local system arch
  begin 'Preflight'
  system=$(uname -s)
  arch=$(uname -m)
  if [[ ${system} != Darwin ]]; then
    ui_fail "This installer is for macOS (found ${system})."
    return 1
  fi
  ui_ok "macOS $(sw_vers -productVersion) on ${arch}"
  if [[ ${arch} != arm64 ]]; then
    if "${files_only}"; then
      ui_warn 'Not Apple Silicon. Fine for --files-only; the Miniconda package is arm64.'
    else
      ui_fail 'The vendor packages are for Apple Silicon. Use --files-only on this Mac.'
      return 1
    fi
  fi
  if xcode-select -p >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
    ui_ok 'Apple Command Line Tools present'
  else
    ui_fail 'Apple Command Line Tools missing. Run: xcode-select --install'
    return 1
  fi
  if "${dry}"; then ui_info 'Dry run: nothing will be written or installed.'; fi
}

# ------------------------------------------------------------------------------
#  Stage 2 - Homebrew, Brewfile packages and Oh My Zsh
# ------------------------------------------------------------------------------

# Put brew on PATH for this script when it is installed but not yet in PATH.
load_brew() {
  local brew_bin brew_env
  if command -v brew >/dev/null 2>&1; then return 0; fi
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x ${brew_bin} ]]; then
      brew_env=$("${brew_bin}" shellenv)
      eval "${brew_env}"
      return 0
    fi
  done
  return 1
}

install_software() {
  local brewfile="${repo}/Brewfile" entries failed
  begin 'Homebrew'
  entries=$(grep -cE '^(brew|cask) ' "${brewfile}")

  # Homebrew itself
  if load_brew; then
    ui_ok "Homebrew present ($(brew --prefix))"
  elif "${dry}"; then
    ui_item ok 'would install' 'Homebrew'
  else
    ui_info 'Installing Homebrew. It may ask for your macOS password.'
    tempdir
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "${scratch}/homebrew.sh"
    /bin/bash "${scratch}/homebrew.sh"
    load_brew
    ui_ok "Homebrew installed ($(brew --prefix))"
  fi

  # Brewfile packages
  if ! command -v brew >/dev/null 2>&1; then
    ui_item ok 'would install' "${entries} Brewfile entries"
  elif brew bundle check --file="${brewfile}" >/dev/null 2>&1; then
    ui_ok "Brewfile satisfied (${entries} entries)"
  elif "${dry}"; then
    ui_item ok 'would install' 'missing Brewfile entries (brew bundle check --verbose lists them)'
  else
    ui_info "Installing missing Brewfile entries (${entries} declared). This can take a while."
    tempdir
    # One package that fails must not stop the whole installer: name it in a
    # warning and carry on with the remaining stages.
    if UI_RUN_LOG="${scratch}/brew-bundle.log" UI_RUN_REWRITE='s/^Using /Already Installed: /' \
      ui_run brew bundle install --no-upgrade --file="${brewfile}"; then
      ui_ok 'Brewfile installed'
    else
      failed=$(sed -n 's/^Installing \(.*\) has failed!$/\1/p' "${scratch}/brew-bundle.log" | paste -sd, - | sed 's/,/, /g')
      ui_warn "Homebrew could not install: ${failed:-some Brewfile entries}. See: brew bundle check --verbose --file=$(ui_path "${brewfile}")"
    fi
  fi

  # Oh My Zsh
  if [[ -d ${HOME}/.oh-my-zsh ]]; then
    ui_ok 'Oh My Zsh present'
  elif "${dry}"; then
    ui_item ok 'would install' 'Oh My Zsh'
  else
    tempdir
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "${scratch}/omz.sh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes ui_run sh "${scratch}/omz.sh"
    ui_ok 'Oh My Zsh installed'
  fi
}

# ------------------------------------------------------------------------------
#  Stage 3 - Vendor packages (AWS CLI v2, Miniconda)
# ------------------------------------------------------------------------------

# install_vendor_pkg <url> <expected signer> [installer options...]
# Download a .pkg, verify its Developer ID signature, then install it.
install_vendor_pkg() {
  local url=$1 signer=$2 pkg signature
  shift 2
  tempdir
  pkg="${scratch}/${url##*/}"
  ui_info "Downloading ${url##*/}"
  curl -fsSL "${url}" -o "${pkg}"
  signature=$(LC_ALL=C pkgutil --check-signature "${pkg}")
  if ! grep -Fq "1. Developer ID Installer: ${signer}" <<<"${signature}"; then
    ui_fail "Unexpected installer signature for ${url##*/}"
    return 1
  fi
  ui_ok "Signature verified: ${signer}"
  ui_info 'Installing. sudo may ask for your macOS password.'
  sudo /usr/sbin/installer -pkg "${pkg}" -target / "$@"
}

# Print the first usable Conda root, if any.
find_conda() {
  local root
  for root in "${CONDA_ROOT:-}" /opt/miniconda3 "${HOME}/miniconda3"; do
    if [[ -n ${root} && -x ${root}/condabin/conda && -r ${root}/etc/profile.d/conda.sh ]]; then
      printf '%s' "${root}"
      return 0
    fi
  done
  return 1
}

install_vendor_tools() {
  local aws_version conda_root
  begin 'Vendor packages'

  # AWS CLI v2
  if aws_version=$(aws --version 2>/dev/null) && [[ ${aws_version} == aws-cli/2.* ]]; then
    ui_ok "AWS CLI present (${aws_version%% *})"
  elif "${dry}"; then
    ui_item ok 'would install' 'AWS CLI v2 (signed AWS package)'
  else
    install_vendor_pkg https://awscli.amazonaws.com/AWSCLIV2.pkg 'AMZN Mobile LLC (94KV3E626L)'
    aws_version=$(/usr/local/bin/aws --version)
    if [[ ${aws_version} != aws-cli/2.* ]]; then
      ui_fail 'AWS CLI v2 did not install correctly.'
      return 1
    fi
    ui_ok "AWS CLI installed (${aws_version%% *})"
  fi

  # Miniconda base
  if conda_root=$(find_conda); then
    ui_ok "Miniconda present (${conda_root})"
  elif "${dry}"; then
    ui_item ok 'would install' 'Miniconda base (signed Anaconda package)'
  else
    tempdir
    # The managed .zshrc already initializes Conda. Disable the package's shell edit.
    cat >"${scratch}/conda-choices.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><array><dict>
  <key>choiceIdentifier</key><string>com.anaconda.pkg.run_conda_init</string>
  <key>choiceAttribute</key><string>selected</string>
  <key>attributeSetting</key><integer>0</integer>
</dict></array></plist>
PLIST
    install_vendor_pkg https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.pkg \
      'Anaconda, Inc (Z5788K4JT7)' -applyChoiceChangesXML "${scratch}/conda-choices.plist"
    ui_ok "Miniconda installed ($(/opt/miniconda3/condabin/conda --version))"
  fi
}

# ------------------------------------------------------------------------------
#  Stage 4 - Fonts
# ------------------------------------------------------------------------------

# font_available <family> - true when macOS has registered this font family.
font_available() {
  local answer
  answer=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.deepUnwrap($.NSFontManager.sharedFontManager.availableFontFamilies).indexOf("'"$1"'") >= 0 ? "yes" : "no"' 2>/dev/null) || true
  [[ ${answer} == yes ]]
}

# register_fonts <dir> - make sure macOS knows the Hack Nerd Font files.
# macOS normally picks up files in ~/Library/Fonts by itself, but not always on
# a new Mac (for example when the folder did not exist at login). Apps then
# show question marks for the prompt icons. In that case the files are
# registered for the current login session; from the next login on, macOS
# finds them in the folder.
register_fonts() {
  local dir=$1 family='Hack Nerd Font Mono'
  if "${dry}"; then return 0; fi
  if font_available "${family}"; then
    ui_ok "macOS has registered ${family}"
    return 0
  fi
  tempdir
  cat >"${scratch}/register-fonts.js" <<'JS'
ObjC.import('Foundation');
ObjC.import('CoreText');
ObjC.bindFunction('CTFontManagerRegisterFontsForURL', ['bool', ['id', 'int', 'void *']]);
function run(argv) {
  for (var i = 0; i < argv.length; i++) {
    // 3 = kCTFontManagerScopeSession: until logout, for every application.
    $.CTFontManagerRegisterFontsForURL($.NSURL.fileURLWithPath(argv[i]), 3, null);
  }
}
JS
  osascript -l JavaScript "${scratch}/register-fonts.js" "${dir}"/HackNerdFont*.ttf >/dev/null 2>&1 || true
  sleep 1
  if font_available "${family}"; then
    ui_ok "Registered ${family} with macOS. Restart open terminals and editors to see the icons."
  else
    ui_warn "macOS has not registered ${family}: prompt icons will show as question marks. Log out and back in, then check Font Book."
  fi
}

install_fonts() {
  local dir="${HOME}/Library/Fonts" manifest="${repo}/config/iterm2/font-sha256.txt" file
  begin 'Fonts'
  if [[ -d ${dir} ]] && (cd "${dir}" && shasum -a 256 -c "${manifest}" >/dev/null 2>&1); then
    ui_ok 'Hack Nerd Font 3.2.1 present (12 faces, checksums match)'
    register_fonts "${dir}"
    return 0
  fi
  if "${dry}"; then
    ui_item ok 'would install' "Hack Nerd Font 3.2.1 in $(ui_path "${dir}")"
    return 0
  fi
  tempdir
  ui_info 'Downloading Hack Nerd Font 3.2.1'
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Hack.zip -o "${scratch}/Hack.zip"
  (cd "${scratch}" && echo '70b2c3e2375f99e9d81b1f01c7ad90efc9d72177ea975fc62f2310fea21e2f18  Hack.zip' | shasum -a 256 -c - >/dev/null)
  unzip -q "${scratch}/Hack.zip" '*.ttf' -d "${scratch}/fonts"
  (cd "${scratch}/fonts" && shasum -a 256 -c "${manifest}" >/dev/null)
  ui_ok 'Download and font checksums verified'
  for file in "${scratch}"/fonts/*.ttf; do copy_file "${file}" "${dir}/${file##*/}"; done
  register_fonts "${dir}"
}

# ------------------------------------------------------------------------------
#  Stage 6 - Managed files
# ------------------------------------------------------------------------------

install_files() {
  local file
  begin 'Managed files'

  # Shell and Git
  for file in .zprofile .zshrc .gitconfig .gitignore_global; do
    copy_file "${repo}/${file}" "${HOME}/${file}"
  done

  # Shell extras. ~/.zshrc sources every ~/.config/zsh/*.zsh file.
  copy_file "${repo}/config/zsh/ec2.zsh" "${zsh_dir}/ec2.zsh"

  # Prompt theme
  copy_file "${repo}/config/oh-my-posh/jandedobbeleer.omp.json" "${HOME}/.config/oh-my-posh/jandedobbeleer.omp.json"

  # iTerm2 profiles
  copy_file "${repo}/config/iterm2/profiles.json" \
    "${HOME}/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"

  # Starter files: SSH client config and 1Password SSH agent key list.
  # Created once from the .example files, then left to you.
  private_dir "${HOME}/.ssh"
  if [[ ! -e ${ssh_config} ]]; then seeded_ssh=true; fi
  seed_file "${repo}/config/ssh/config.example" "${ssh_config}" 600
  private_dir "$(dirname "${agent_config}")"
  if [[ ! -e ${agent_config} ]]; then seeded_agent=true; fi
  seed_file "${repo}/config/1password/agent.toml.example" "${agent_config}" 600

  # iTerm2 default profile and general settings
  configure_iterm2

  # Keyboard key swap, reapplied at login
  configure_keyboard
}

# configure_iterm2 - apply the iTerm2 settings that live outside a profile:
# the default profile and the general settings in config/iterm2/preferences.tsv.
# iTerm2 writes its settings back when it quits, so nothing is changed while it
# is running.
configure_iterm2() {
  local name kind value current wanted changed=0 same=0
  local list="${repo}/config/iterm2/preferences.tsv"
  if [[ ! -d ${iterm_app} && ! -d ${HOME}${iterm_app} ]]; then
    ui_info 'iTerm2 is not installed yet. Run ./install.sh --files-only after installing it to apply its settings.'
    return 0
  fi
  if pgrep -xq iTerm2; then
    ui_warn 'iTerm2 is running, so its general settings were not applied. Quit iTerm2 and run ./install.sh --files-only from Terminal.'
    return 0
  fi
  while IFS=$'\t' read -r name kind value; do
    if [[ -z ${name} || ${name} == '#'* ]]; then continue; fi
    wanted=${value}
    if [[ ${kind} == bool ]]; then
      if [[ ${value} == true ]]; then wanted=1; else wanted=0; fi
    fi
    current=$(defaults read "${iterm_domain}" "${name}" 2>/dev/null) || current=''
    current=${current//\\\\/\\} # defaults prints a backslash as two
    if [[ ${current} == "${wanted}" ]]; then
      same=$((same + 1))
      continue
    fi
    changed=$((changed + 1))
    if "${dry}"; then continue; fi
    if ((changed == 1)); then
      ensure_backup
      defaults export "${iterm_domain}" "${backup}/iterm2-preferences.plist" 2>/dev/null || true
    fi
    defaults write "${iterm_domain}" "${name}" "-${kind}" "${value}"
  done <"${list}"
  if ((changed == 0)); then
    ui_item skip unchanged "iTerm2 settings (${same} already set, default profile: Dotfiles Main Profile)"
  elif "${dry}"; then
    ui_item ok 'would set' "iTerm2 settings (${changed} to change, ${same} already set)"
  else
    ui_item ok updated "iTerm2 settings (${changed} changed, ${same} already set)" 'backup kept'
  fi
}

# configure_keyboard - install the key swap script and the LaunchAgent that
# applies the swap at every login, then load the agent so the swap is active
# right away. The swap uses hidutil, which is part of macOS; the agent calls it
# directly and the script is for the terminal. macOS only applies the swap when
# /usr/bin/hidutil is allowed under Input Monitoring, which only the user can
# do, hence the reminder.
configure_keyboard() {
  local agent="${HOME}/Library/LaunchAgents/${keyboard_label}.plist"
  local domain before try loaded=false
  before=$((count_new + count_updated))
  copy_file "${repo}/scripts/keyboard-remap.sh" "${bin_dir}/keyboard-remap" 755
  copy_file "${repo}/config/keyboard/${keyboard_label}.plist" "${agent}"

  if [[ -d ${karabiner_app} ]]; then
    ui_warn 'Karabiner-Elements is installed. It takes over the keyboard, so this key swap and the macOS Modifier Keys setting have no effect until it is uninstalled.'
  fi
  if "${dry}"; then
    ui_item ok 'would load' "login agent ${keyboard_label}"
    return 0
  fi
  if "${skip_launchctl}"; then
    ui_info "Login agent ${keyboard_label} installed but not loaded (DOTFILES_SKIP_LAUNCHCTL is set)."
    return 0
  fi

  domain="gui/$(id -u)"
  if launchctl print "${domain}/${keyboard_label}" >/dev/null 2>&1; then loaded=true; fi
  if "${loaded}" && ((count_new + count_updated == before)); then
    ui_item skip unchanged "login agent ${keyboard_label} (loaded)"
    return 0
  fi
  # Reload: unload the old definition if there is one, then load the file.
  # launchd needs a moment after unloading, hence the retries.
  launchctl bootout "${domain}/${keyboard_label}" >/dev/null 2>&1 || true
  for try in 1 2 3; do
    if launchctl bootstrap "${domain}" "${agent}" >/dev/null 2>&1; then
      ui_item ok loaded "login agent ${keyboard_label}"
      ui_info 'The key swap needs /usr/bin/hidutil allowed once in System Settings > Privacy & Security > Input Monitoring. See README.md, step 7.'
      return 0
    fi
    sleep 1
  done
  ui_warn "Could not load the login agent ${keyboard_label} (attempt ${try}). Apply the key swap now with: keyboard-remap on. It loads by itself at the next login."
}

# ------------------------------------------------------------------------------
#  Stage 7 - Checks
# ------------------------------------------------------------------------------

# The SSH config selects 1Password keys by their public key file. Those .pub
# files are never in the repo, so report the active IdentityFile lines that
# still hold a placeholder or point at a file that does not exist yet.
check_ssh_keys() {
  local key path source total=0 open=0
  begin 'Checks'
  source=${ssh_config}
  # In a dry run on a new Mac the file does not exist yet: check the starter.
  if [[ ! -f ${source} ]]; then source="${repo}/config/ssh/config.example"; fi
  while IFS= read -r key; do
    total=$((total + 1))
    path=${key/#\~/${HOME}}
    if [[ ${key} == *'<'*'>'* ]]; then
      open=$((open + 1))
      ui_warn "Placeholder in $(ui_path "${ssh_config}"): IdentityFile ${key}"
    elif [[ ! -f ${path} ]]; then
      open=$((open + 1))
      ui_warn "Public key missing: ${key} (export it from 1Password)"
    fi
  done < <(awk 'tolower($1) == "identityfile" { print $2 }' "${source}" | sort -u)
  keys_open=${open}
  if ((total == 0)); then
    ui_ok "$(ui_path "${ssh_config}") has no IdentityFile lines to check"
  elif ((open == 0)); then
    ui_ok "All ${total} key files referenced by $(ui_path "${ssh_config}") are present"
  fi
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
  if ((count_kept > 0)); then printf ', %d kept' "${count_kept}"; fi
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
  ui_info 'Quit and reopen your terminal and editor to load the new shell setup and fonts.'
  if "${seeded_ssh}"; then
    ui_info "Fill in the placeholders in $(ui_path "${ssh_config}") and uncomment the examples you need."
  fi
  if "${seeded_agent}"; then
    ui_info "Review $(ui_path "${agent_config}"): it offers the SSH keys of your Private vault."
  fi
  if ((keys_open > 0)); then
    ui_info 'Export the public keys listed above from 1Password into ~/.ssh/.'
  fi
  ui_info 'Machine-only shell settings go in ~/.config/zsh/local.zsh (never replaced).'
  ui_info "Remaining apps and sign-ins: $(ui_path "${repo}/README.md")"
}

# ------------------------------------------------------------------------------
#  Main
# ------------------------------------------------------------------------------

main() {
  local mode='install' scope='software, fonts and files'
  parse_args "$@"
  trap on_exit EXIT

  if "${dry}"; then mode='dry run'; fi
  if "${files_only}"; then
    scope='files only'
    UI_TOTAL=4
  else
    UI_TOTAL=7
  fi
  ui_banner 'dotfiles installer' Mode "${mode}" Scope "${scope}" Source "$(ui_path "${repo}")"

  preflight
  if ! "${files_only}"; then
    install_software
    install_vendor_tools
    install_fonts
  fi
  preserve_git_identity
  install_files
  check_ssh_keys
  summary
}

main "$@"
