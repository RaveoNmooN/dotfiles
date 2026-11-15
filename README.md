# Dotfiles

[![pre-commit](https://github.com/RaveoNmooN/dotfiles/actions/workflows/pre-commit.yml/badge.svg)](https://github.com/RaveoNmooN/dotfiles/actions/workflows/pre-commit.yml)
[![Last commit](https://img.shields.io/github/last-commit/RaveoNmooN/dotfiles)](https://github.com/RaveoNmooN/dotfiles/commits/main)
[![License: MIT](https://img.shields.io/github/license/RaveoNmooN/dotfiles)](LICENSE)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-fe5196?logo=conventionalcommits&logoColor=white)](https://www.conventionalcommits.org)
![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)
![Windows](https://img.shields.io/badge/Windows-0078D4)

My environment customizations for macOS, Linux and Windows: shell setup, prompt, Git aliases, editor and terminal preferences. Each platform has its own folder and its own README.

## Sections

| Folder | Platform | What is inside | Setup |
|---|---|---|---|
| [MacOS/](MacOS) | macOS (Apple Silicon) | Installer for Homebrew tools, Zsh with Oh My Zsh and Oh My Posh, fzf helpers, Git config, iTerm2 profiles, a keyboard key swap, starter SSH and 1Password agent config, EC2 Instance Connect helpers | [MacOS/README.md](MacOS/README.md) |
| [Linux/](Linux) | Linux | Installer for the Bash prompt, aliases and completion, Vim defaults, Git config | [Linux/README.md](Linux/README.md) |
| [Windows/](Windows) | Windows | PowerShell profile with Oh My Posh, Terminal-Icons, PSReadLine, fzf and z, Git config | [Windows/README.md](Windows/README.md) |
| [lib/](lib) | macOS and Linux | Shell helpers shared by the two installers: terminal output, file copy with backup, Git identity | used by the installers |

## Layout

```text
dotfiles/
├── MacOS/        install.sh, .zshrc, .gitconfig, Brewfile, config/, scripts/, inventory/
├── Linux/        install.sh, .bashrc, .vimrc, .gitconfig
├── Windows/      user_profile.ps1, .gitconfig
├── lib/          shell helpers shared by the two installers
└── .github/      workflow that runs the pre-commit hooks
```

## Quick start

```bash
git clone https://github.com/RaveoNmooN/dotfiles.git ~/dotfiles
```

**macOS and Linux**: one installer per platform. `--dry-run` shows every change first. Identical files are skipped, and a file that would be replaced is first copied to `~/.dotfiles-backup/<timestamp>/`.

```bash
~/dotfiles/MacOS/install.sh --dry-run
```

```bash
~/dotfiles/Linux/install.sh --dry-run
```

Run the same command without `--dry-run` to apply.

**Windows**: follow the numbered steps in [Windows/README.md](Windows/README.md).

## Git configuration

Each platform folder has one complete `.gitconfig` that installs as `~/.gitconfig`. The aliases and defaults are the same in all three; only the platform part differs:

| File | Line endings (`core.autocrlf`) | Extra |
|---|---|---|
| [MacOS/.gitconfig](MacOS/.gitconfig) | `input`: commit LF, leave files as they are on checkout | global ignore file `~/.gitignore_global`, Sourcetree diff and merge tools |
| [Linux/.gitconfig](Linux/.gitconfig) | `input` | none |
| [Windows/.gitconfig](Windows/.gitconfig) | `true`: commit LF, check out CRLF | none |

`core.autocrlf` is only the fallback for repositories that say nothing about line endings. A repository's own [.gitattributes](.gitattributes) takes precedence and is the reliable way to keep line endings consistent across platforms.

None of the files contains a name or an e-mail address. Each ends by including `~/.gitconfig.local`, which holds the identity and signing settings of one machine and is never tracked. The macOS and Linux installers ask for name and e-mail when that file has none. When you change an alias, change it in all three files.

## Useful shortcuts

Shell aliases, the same on all three platforms:

| Alias | Runs |
|---|---|
| `g` | `git` |
| `k` | `kubectl` |
| `d` | `docker` |
| `dco` | `docker-compose` |
| `trf` | `terraform` |

Git aliases. Because `g` is `git`, both forms work everywhere:

| Short form | Long form | Does |
|---|---|---|
| `g s` | `git s` | status |
| `g p` | `git p` | push |
| `g fs` | `git fs` | fetch, then status |
| `g logone` | `git logone` | graph of all branches, one line per commit |
| `g logp` | `git logp` | graph of all branches, full |
| `g ca "<message>"` | `git ca "<message>"` | add everything and commit |
| `g amend` | `git amend` | add staged files to the last commit, same message |

macOS adds fzf helpers such as `fcd` (change directory), `ch` (search history), `fbranch` (switch branch), `fkctx` and `fkns` (kubectl context and namespace); the full list is at the top of [MacOS/.zshrc](MacOS/.zshrc).

## What is not in this repo

The repository is public. It contains no private keys, public key files, tokens, real host names or addresses, cloud account settings, names or e-mail addresses. Files that need such values ship as `.example` starters with placeholders, and machine-only settings live in files that are never tracked:

| File on the machine | Holds |
|---|---|
| `~/.gitconfig.local` | Git name, e-mail, signing |
| `~/.config/zsh/local.zsh` (macOS), `~/.bashrc.local` (Linux) | private shell settings |
| `~/.ssh/config`, 1Password `agent.toml` (macOS) | real hosts and keys; seeded once from the `.example` files, then never replaced |

## Working on this repo

[pre-commit](https://pre-commit.com) runs the checks. Install the hooks once after cloning:

```bash
pre-commit install
```

Run everything by hand at any time:

```bash
pre-commit run --all-files
```

| Check | Tool |
|---|---|
| Secrets and private keys | gitleaks, detect-private-key |
| Shell scripts | ShellCheck; `zsh -n` for the Zsh files |
| Python | Ruff (lint and format) |
| YAML, JSON, TOML | yamllint and syntax checks |
| File hygiene | trailing whitespace, final newline, LF line endings, executable bits, large files |
| Commit messages | [Conventional Commits](https://www.conventionalcommits.org), for example `feat(macos): add ec2 helpers` |

The same hooks run on GitHub for every push and pull request ([workflow](.github/workflows/pre-commit.yml)). [.editorconfig](.editorconfig) makes editors write files the way the hooks expect. [Dependabot](.github/dependabot.yml) opens a pull request each week when a pinned action or hook has a newer version.

## License

[MIT](LICENSE)
