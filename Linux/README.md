# Linux dotfiles

Bash, Vim and Git settings for a Linux machine. The installer copies three files and installs no packages.

## What is included

| In the repo | On the machine | What it does |
|---|---|---|
| [.bashrc](.bashrc) | `~/.bashrc.d/dotfiles.sh` | Coloured prompt with the Git branch, history settings, aliases, completion for `kubectl` and `terraform`, fzf key bindings |
| [.vimrc](.vimrc) | `~/.vimrc` | Syntax highlighting, search highlighting, spaces for tabs, two-space YAML indentation |
| [.gitconfig](.gitconfig) | `~/.gitconfig` | Git aliases and defaults, `core.autocrlf = input` |

The distribution's own `~/.bashrc` is kept. The installer appends one small block that sources `~/.bashrc.d/*.sh`, unless the file already does that (Fedora and RHEL do by default). To remove the customizations again, delete `~/.bashrc.d/dotfiles.sh`.

## Install

Git is the only requirement.

```bash
git clone https://github.com/RaveoNmooN/dotfiles.git ~/dotfiles
```

Preview, then install:

```bash
~/dotfiles/Linux/install.sh --dry-run
```

```bash
~/dotfiles/Linux/install.sh
```

What it does, in order:

1. **Preflight**: checks that Git is present.
2. **Git identity**: moves name, e-mail and signing settings from an existing `~/.gitconfig` into `~/.gitconfig.local`. On a machine without an identity it asks for name and e-mail.
3. **Files**: copies the three files from the table. Identical files are skipped; a file that would be replaced is first copied to `~/.dotfiles-backup/<timestamp>/`.
4. **Shell hook**: makes `~/.bashrc` source `~/.bashrc.d/*.sh`, once.

Open a new shell afterwards, or run `source ~/.bashrc`. Set `NO_COLOR=1` for plain installer output.

## Shortcuts

| Shortcut | Runs |
|---|---|
| `d`, `dco` | `docker`, `docker-compose` |
| `k` | `kubectl`, with completion |
| `g` | `git` |
| `trf` | `terraform`, with completion |
| `h` | `history` |
| `rm`, `cp`, `mv` | ask before deleting or overwriting |
| Ctrl+R, Ctrl+T | fzf history search and file picker (fzf 0.48 or newer) |
| `_sh` in Vim | expands to `#!/bin/bash` |

The Git aliases (`git s`, `git logone`, `git ca`, ...) are listed in [.gitconfig](.gitconfig).

## Machine-only settings

These files are yours. The installer never creates or replaces them, and they are sourced last, so they can override anything above.

| File | Use it for |
|---|---|
| `~/.bashrc.local` | Extra aliases, environment variables, anything that should not be public |
| `~/.gitconfig.local` | Git name, e-mail and signing |

To change the identity later:

```bash
git config --file ~/.gitconfig.local --edit
```
