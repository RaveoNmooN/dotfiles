#!/usr/bin/env bash
# ==============================================================================
#  keyboard-remap - swap the two ISO keys with macOS's own hidutil
# ==============================================================================
#  Installed as ~/.local/bin/keyboard-remap by install.sh, for use in a
#  terminal. The LaunchAgent com.dotfiles.keyboard-remap applies the same swap
#  at every login by calling hidutil directly; keep the mapping in
#  config/keyboard/com.dotfiles.keyboard-remap.plist in step with this file.
#
#  Usage
#    keyboard-remap [on|off|status]
#
#    on       swap the two keys (default)
#    off      remove the swap
#    status   show the mapping that is active now
#
#  What it swaps, on every keyboard:
#    the key left of "1"  <->  the key next to left Shift
#  so that ~ and ` sit where they are on a US keyboard.
#
#  Notes
#    - hidutil is part of macOS. No extra software and no sudo.
#    - macOS only applies the mapping when the program that asked for it is
#      allowed under Privacy & Security > Input Monitoring. In a terminal that
#      is the terminal app. If "status" lists the swap but the keys do not
#      change, that permission is missing.
#    - The mapping lasts until restart, which is why the LaunchAgent applies
#      it again at login.
#    - "on" and "off" replace the whole hidutil key mapping list.
#    - Control, Option and Command are set in System Settings > Keyboard >
#      Keyboard Shortcuts > Modifier Keys, not here.
# ==============================================================================

set -euo pipefail

# HID usage IDs: 0x07 is the keyboard page, the last two digits are the key.
key_left_of_one=0x700000035    # grave accent and tilde
key_next_to_shift=0x700000064  # non-US backslash (the extra ISO key)

swap="{\"HIDKeyboardModifierMappingSrc\":${key_left_of_one},\"HIDKeyboardModifierMappingDst\":${key_next_to_shift}}"
swap+=",{\"HIDKeyboardModifierMappingSrc\":${key_next_to_shift},\"HIDKeyboardModifierMappingDst\":${key_left_of_one}}"

case "${1:-on}" in
  on)
    /usr/bin/hidutil property --set "{\"UserKeyMapping\":[${swap}]}" >/dev/null
    echo 'Key swap is on.'
    ;;
  off)
    /usr/bin/hidutil property --set '{"UserKeyMapping":[]}' >/dev/null
    echo 'Key swap is off.'
    ;;
  status)
    /usr/bin/hidutil property --get UserKeyMapping
    ;;
  -h | --help)
    echo 'Usage: keyboard-remap [on|off|status]'
    ;;
  *)
    echo 'Usage: keyboard-remap [on|off|status]' >&2
    exit 2
    ;;
esac
