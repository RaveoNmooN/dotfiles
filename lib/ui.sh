#!/usr/bin/env bash
# ==============================================================================
#  ui.sh - terminal output helpers shared by the installers
# ==============================================================================
#  Source this file; do not execute it.
#
#  Works with the stock macOS bash 3.2, so it can run on a brand-new Mac before
#  Homebrew exists. Colours and glyphs are used only when stdout is a terminal.
#  Set NO_COLOR=1 to force plain output.
#
#  Layout helpers    ui_banner  ui_section  ui_rule
#  Status lines      ui_ok  ui_skip  ui_info  ui_warn  ui_fail  ui_item
#                    ui_warnings_report
#  Running commands  ui_run
#  Asking            ui_ask  ui_confirm
#  Misc              ui_path  ui_elapsed
# ==============================================================================

# ------------------------------------------------------------------------------
#  Colours and glyphs
# ------------------------------------------------------------------------------

if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
  UI_BOLD=$'\033[1m'
  UI_DIM=$'\033[2m'
  UI_RED=$'\033[31m'
  UI_GREEN=$'\033[32m'
  UI_YELLOW=$'\033[33m'
  UI_BLUE=$'\033[34m'
  UI_CYAN=$'\033[36m'
  UI_RESET=$'\033[0m'
else
  UI_BOLD='' UI_DIM='' UI_RED='' UI_GREEN='' UI_YELLOW='' UI_BLUE='' UI_CYAN='' UI_RESET=''
fi

case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8* | *utf8* | *UTF8* | *utf-8*)
    UI_G_OK='✔' UI_G_SKIP='◦' UI_G_WARN='▲' UI_G_FAIL='✖' UI_G_INFO='›' UI_G_STEP='▸' UI_G_PIPE='│' UI_G_RULE='━'
    ;;
  *)
    UI_G_OK='+' UI_G_SKIP='-' UI_G_WARN='!' UI_G_FAIL='x' UI_G_INFO='>' UI_G_STEP='==>' UI_G_PIPE='|' UI_G_RULE='='
    ;;
esac

UI_STEP=0     # current section number
UI_TOTAL=0    # total sections; set by the caller to get "[2/6]" numbering
UI_WARNINGS=0 # number of ui_warn calls
UI_WARNING_LIST=() # text of every warning, repeated by ui_warnings_report

# ------------------------------------------------------------------------------
#  Layout
# ------------------------------------------------------------------------------

# ui_rule - print a full-width horizontal rule.
ui_rule() {
  local i line=''
  for ((i = 0; i < 62; i++)); do line+=${UI_G_RULE}; done
  printf '%s%s%s\n' "${UI_DIM}" "${line}" "${UI_RESET}"
}

# ui_banner <title> [<label> <value>]... - title block with aligned key/values.
ui_banner() {
  local title=$1
  shift
  printf '\n'
  ui_rule
  printf '  %s%s%s\n' "${UI_BOLD}" "${title}" "${UI_RESET}"
  while (($# >= 2)); do
    printf '  %s%-10s%s %s\n' "${UI_DIM}" "$1" "${UI_RESET}" "$2"
    shift 2
  done
  ui_rule
}

# ui_section <title> - numbered section heading.
ui_section() {
  UI_STEP=$((UI_STEP + 1))
  printf '\n%s%s' "${UI_BOLD}${UI_BLUE}" "${UI_G_STEP}"
  if ((UI_TOTAL > 0)); then printf ' [%d/%d]' "${UI_STEP}" "${UI_TOTAL}"; fi
  printf ' %s%s\n' "$1" "${UI_RESET}"
}

# ------------------------------------------------------------------------------
#  Status lines
# ------------------------------------------------------------------------------

ui_ok() { printf '  %s%s%s %s\n' "${UI_GREEN}" "${UI_G_OK}" "${UI_RESET}" "$*"; }
ui_skip() { printf '  %s%s %s%s\n' "${UI_DIM}" "${UI_G_SKIP}" "$*" "${UI_RESET}"; }
ui_info() { printf '  %s%s%s %s\n' "${UI_CYAN}" "${UI_G_INFO}" "${UI_RESET}" "$*"; }
ui_fail() { printf '  %s%s %s%s\n' "${UI_RED}" "${UI_G_FAIL}" "$*" "${UI_RESET}" >&2; }
ui_warn() {
  UI_WARNINGS=$((UI_WARNINGS + 1))
  UI_WARNING_LIST+=("$*")
  printf '  %s%s %s%s\n' "${UI_YELLOW}" "${UI_G_WARN}" "$*" "${UI_RESET}"
}

# ui_warnings_report - print every warning of this run again, numbered. Call
# it from the summary, so nobody has to scroll back to find what went wrong.
ui_warnings_report() {
  local i
  if ((UI_WARNINGS == 0)); then return 0; fi
  printf '\n%s%sWarnings%s\n' "${UI_BOLD}" "${UI_YELLOW}" "${UI_RESET}"
  for ((i = 0; i < UI_WARNINGS; i++)); do
    printf '  %s%d.%s %s\n' "${UI_YELLOW}" $((i + 1)) "${UI_RESET}" "${UI_WARNING_LIST[i]}"
  done
}

# ui_item <ok|skip|warn> <status word> <text> [<note>] - aligned status row,
# used for per-file results: "✔ updated    ~/.zshrc  (backup kept)".
ui_item() {
  local kind=$1 status=$2 text=$3 note=${4:-} colour glyph
  case "${kind}" in
    ok) colour=${UI_GREEN} glyph=${UI_G_OK} ;;
    warn) colour=${UI_YELLOW} glyph=${UI_G_WARN} ;;
    *) colour=${UI_DIM} glyph=${UI_G_SKIP} ;;
  esac
  printf '  %s%s %-14s%s %s' "${colour}" "${glyph}" "${status}" "${UI_RESET}" "${text}"
  if [[ -n ${note} ]]; then printf '  %s(%s)%s' "${UI_DIM}" "${note}" "${UI_RESET}"; fi
  printf '\n'
}

# ------------------------------------------------------------------------------
#  Running commands
# ------------------------------------------------------------------------------

# ui_run <command> [args...] - run a command with its output indented under the
# current section. Returns the command's own exit status.
# Optional, set for one call:
#   UI_RUN_LOG=<file>      also save the raw output to a file
#   UI_RUN_REWRITE=<sed>   sed expression applied to each output line
ui_run() {
  local status=0 log=${UI_RUN_LOG:-/dev/null} rewrite=${UI_RUN_REWRITE:-s/^//}
  printf '  %s$ %s%s\n' "${UI_DIM}" "$*" "${UI_RESET}"
  set +e
  "$@" 2>&1 | tee "${log}" | sed -e "${rewrite}" -e "s/^/    ${UI_G_PIPE} /"
  status=${PIPESTATUS[0]}
  set -e
  return "${status}"
}

# ------------------------------------------------------------------------------
#  Asking
# ------------------------------------------------------------------------------

# ui_ask <label> [<default>] [hidden] - prompt on stderr, print the answer on
# stdout. "hidden" turns off echo, for values that must not appear on screen.
ui_ask() {
  local label=$1 default_value=${2:-} mode=${3:-} value=''
  if [[ -n ${default_value} ]]; then
    printf '  %s?%s %s %s[%s]%s: ' "${UI_CYAN}" "${UI_RESET}" "${label}" "${UI_DIM}" "${default_value}" "${UI_RESET}" >&2
  else
    printf '  %s?%s %s: ' "${UI_CYAN}" "${UI_RESET}" "${label}" >&2
  fi
  if [[ ${mode} == hidden ]]; then
    IFS= read -rs value || true
    printf '\n' >&2
  else
    IFS= read -r value || true
  fi
  printf '%s' "${value:-${default_value}}"
}

# ui_confirm <question> - yes/no question, default yes. Returns 0 for yes.
ui_confirm() {
  local answer=''
  printf '  %s?%s %s %s[Y/n]%s: ' "${UI_CYAN}" "${UI_RESET}" "$1" "${UI_DIM}" "${UI_RESET}" >&2
  IFS= read -r answer || true
  case "${answer}" in
    '' | y | Y | yes | YES | Yes) return 0 ;;
    *) return 1 ;;
  esac
}

# ------------------------------------------------------------------------------
#  Misc
# ------------------------------------------------------------------------------

# ui_path <path> - print a path with $HOME shortened to "~".
ui_path() {
  local path=$1
  if [[ ${path} == "${HOME}"/* ]]; then
    # A literal "~" is wanted here: this is for display, not for expansion.
    # shellcheck disable=SC2088
    printf '~/%s' "${path#"${HOME}"/}"
  else
    printf '%s' "${path}"
  fi
}

# ui_elapsed - print the time since the script started, e.g. "1m 12s".
ui_elapsed() {
  local total=${SECONDS}
  if ((total >= 60)); then
    printf '%dm %ds' $((total / 60)) $((total % 60))
  else
    printf '%ds' "${total}"
  fi
}
