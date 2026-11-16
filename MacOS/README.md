# macOS dotfiles

Set up or restore an Apple Silicon Mac from this folder with one installer.

Follow the sections in order on a new or reinstalled Mac.

1. [What you get](#1-what-you-get)
2. [Before you start](#2-before-you-start)
3. [Run the installer](#3-run-the-installer)
4. [Right after the installer](#4-right-after-the-installer)
5. [Apps to install afterwards](#5-apps-to-install-afterwards)
6. [AWS and EC2 helpers](#6-aws-and-ec2-helpers)
7. [Verify](#7-verify)
8. [Keep the repo current](#8-keep-the-repo-current)
9. [Reference](#9-reference)

## 1. What you get

| Area | What is set up |
|---|---|
| Software | Homebrew, the [Brewfile](Brewfile) tools, 1Password CLI, Bruno, DBeaver and Radar. AWS CLI v2 and Miniconda base from signed vendor packages. Hack Nerd Font. |
| Shell | `~/.zshrc` and `~/.zprofile`: Oh My Zsh, Oh My Posh prompt, fzf helpers, completions, Conda. EC2 Instance Connect helpers in `~/.config/zsh/ec2.zsh`. |
| SSH and 1Password | Starter `~/.ssh/config` and 1Password SSH agent key list, with placeholders and commented examples. |
| Preferences | Git defaults and aliases, iTerm2 profiles and settings, a keyboard key swap that is reapplied at login. |

Where each repo file ends up:

| In the repo | On the Mac | Behaviour |
|---|---|---|
| `.zshrc`, `.zprofile`, `.gitconfig`, `.gitignore_global` | Same name in `~` | Managed |
| `config/zsh/ec2.zsh` | `~/.config/zsh/ec2.zsh` | Managed |
| `config/oh-my-posh` | `~/.config/oh-my-posh` | Managed |
| `scripts/keyboard-remap.sh` | `~/.local/bin/keyboard-remap` | Managed |
| `config/keyboard/com.dotfiles.keyboard-remap.plist` | `~/Library/LaunchAgents/` | Managed, loaded by the installer |
| `config/iterm2/profiles.json` | `~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json` | Managed |
| `config/iterm2/preferences.tsv` | iTerm2's macOS preferences: default profile and general settings | Applied while iTerm2 is not running |
| `config/ssh/config.example` | `~/.ssh/config` | Seeded once |
| `config/1password/agent.toml.example` | `~/.config/1Password/ssh/agent.toml` | Seeded once |

**Managed** files are replaced whenever the repo copy changes; the old file goes to `~/.dotfiles-backup/<timestamp>/` first. **Seeded** files are created only when they do not exist. After that they are yours and the installer never touches them, because they hold your own hosts and keys.

Never in the repo: private keys, public key files, real host names and addresses, AWS account settings, the Git identity of the device, app sign-ins and app data.

## 2. Before you start

1. **Update macOS** and sign in to the Mac.
2. **Install Apple Command Line Tools** (this provides `git`) and wait until it finishes:

   ```bash
   xcode-select --install
   ```

3. **Install 1Password** from 1password.com and sign in. In 1Password → Settings → Developer, turn on **Use the SSH agent** and **Integrate with 1Password CLI**. SSH and Git commit signing get their keys from it.
4. **Clone the repo.** It is public, so HTTPS needs no key:

   ```bash
   git clone https://github.com/RaveoNmooN/dotfiles.git ~/dotfiles
   ```

   ```bash
   cd ~/dotfiles/MacOS
   ```

   Clone the whole repository: the installer uses the helpers in [../lib/](../lib).

Recommended before the installer: install **iTerm2** (see [section 5](#5-apps-to-install-afterwards)), then quit it again. The installer applies iTerm2's general settings and default profile only while iTerm2 is not running, so run the installer from the built-in Terminal app. Installing iTerm2 afterwards just means one more `./install.sh --files-only` run.

## 3. Run the installer

Preview first, then run.

```bash
./install.sh --dry-run
```

```bash
./install.sh
```

| Option | Effect |
|---|---|
| `--dry-run` | Shows every change. Writes and installs nothing. |
| `--files-only` | Copies the files only. No Homebrew, vendor packages or fonts. |
| `NO_COLOR=1` | Plain output without colours. |

What it does, in order:

1. **Preflight**: checks macOS, Apple Silicon and the Command Line Tools.
2. **Homebrew**: installs Homebrew if missing, the missing [Brewfile](Brewfile) entries, and Oh My Zsh.
3. **Vendor packages**: AWS CLI v2 and Miniconda base, each after its installer signature is verified.
4. **Fonts**: the twelve Hack Nerd Font 3.2.1 faces, checksum verified, and a check that macOS has registered them.
5. **Git identity**: moves name, e-mail, signing settings and commit template from an existing `~/.gitconfig` into `~/.gitconfig.local`. On a Mac without an identity it asks for name and e-mail.
6. **Managed files**: copies the files from the table in section 1, seeds the two starter files, applies the iTerm2 settings, and loads the keyboard key swap.
7. **Checks**: lists placeholders and missing public key files in `~/.ssh/config`.

Homebrew and the vendor installers ask for the macOS password. Identical files are skipped. The installer can be run again at any time.

## 4. Right after the installer

1. **Restart your terminal and editor** (quit iTerm2 and VS Code completely, then reopen) so they load the new shell setup and the new fonts.

   If the prompt shows question marks or empty boxes where icons should be, the font is not active yet. The icons are characters that only the Nerd Font contains. Open Font Book and search for "Hack": if it is not listed, log out of macOS and back in. In VS Code, also check that Settings → Terminal › Integrated: Font Family is `'Hack Nerd Font Mono', monospace`.
2. **Fill in the placeholders.** Two files were seeded with `<placeholder>` values and commented examples:

   | File | What to change |
   |---|---|
   | `~/.ssh/config` | The `IdentityFile` of the GitHub block. Uncomment and adjust the examples you need (second GitHub account, Git server on a custom port, host by IP, jump host, `ProxyJump`, wildcard hosts, key file on disk). |
   | `~/.config/1Password/ssh/agent.toml` | Works as seeded (all SSH keys of the Private vault). Uncomment an entry to offer a specific item or another vault. |

3. **Create the public key files.** The SSH config selects a 1Password key by its public key file. Open the SSH key item in 1Password, copy the public key and save it under the name used in `~/.ssh/config`, for example:

   ```bash
   pbpaste > ~/.ssh/github.pub
   ```

4. **Test SSH** (1Password asks for approval):

   ```bash
   ssh -T git@github.com
   ```

   Once this works you can switch the clone to SSH:

   ```bash
   git -C ~/dotfiles remote set-url origin git@github.com:RaveoNmooN/dotfiles.git
   ```

5. **Check the Git identity of this Mac.** The installer has migrated it or asked for it; it is in `~/.gitconfig.local`, which the managed `~/.gitconfig` includes. For signed commits add 1Password's Git signing setup to the same file.

   ```bash
   git config --file ~/.gitconfig.local --edit
   ```

6. **iTerm2**: the installer makes **Dotfiles Main Profile** the default and applies the general settings (tab bar style, hidden scrollbar, dimming) from [config/iterm2/preferences.tsv](config/iterm2/preferences.tsv). If it reported that iTerm2 was running or not installed, quit or install iTerm2 and run `./install.sh --files-only` from the Terminal app. The prompt theme is `~/.config/oh-my-posh/jandedobbeleer.omp.json`.
7. **Keyboard**: the installer swaps the key left of `1` with the key next to left Shift, on every keyboard, so that `~` and `` ` `` sit where they are on a US keyboard. It uses `hidutil`, which is part of macOS, so there is nothing to install. It needs one permission, which only you can give, once per Mac:

   System Settings → Privacy & Security → Input Monitoring → `+`, press Cmd+Shift+G, enter `/usr/bin/hidutil`, and switch it on.

   Without it the login agent still runs and `keyboard-remap status` still lists the swap, but the keys do not change after a restart. The commands below work from a terminal that itself has Input Monitoring (iTerm2 asks for it).

   | Command | Does |
   |---|---|
   | `keyboard-remap status` | shows the active mapping |
   | `keyboard-remap off` | removes the swap until the next restart |
   | `keyboard-remap on` | applies it again |

   The mapping is lost at every restart, so a LaunchAgent (`~/Library/LaunchAgents/com.dotfiles.keyboard-remap.plist`) applies it at each login. It calls `/usr/bin/hidutil` directly instead of the script, so that the permission above is the only one needed. A LaunchAgent is macOS's way to run a command for you when you log in; it runs once, as you, and then exits. It is listed in System Settings → General → Login Items, under "Allow in the Background".

8. **Machine-only shell settings** go in `~/.config/zsh/local.zsh`. The installer never creates or replaces that file and the shell sources it last. Use it for anything that should not be public: extra aliases, `AWS_PROFILE`, host shortcuts.

## 5. Apps to install afterwards

The apps I commonly use are not installed by the installer. Install them by hand; the list with sources is in [inventory/software.tsv](inventory/software.tsv).

## 6. AWS and EC2 helpers

AWS account settings are not part of this repo. Create profiles yourself, for example with `aws configure sso`, and sign in with `aws sso login --profile <profile>`.

The EC2 helpers work with whatever AWS profile is active (`AWS_PROFILE`). They only need the instance ID:

| Command | Does |
|---|---|
| `ec2_connect [instance-id]` | Opens an SSH session. |
| `ec2_copy_file [instance-id] [remote-path] [local-path]` | Downloads a file. |
| `ec2_paste_file [instance-id] [local-path] [remote-path]` | Uploads a file. |

Each command looks up the availability zone and IP address of the instance, pushes a public key with EC2 Instance Connect (valid for 60 seconds) and connects. Missing arguments are asked for.

The key is the local pair `~/.ssh/ec2_instance_connect{,.pub}` when it exists. Otherwise set `EC2_CONNECT_1PASSWORD_ITEM` and the private key is read from that 1Password item into a temporary agent, without being written to disk. To create the local pair:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ec2_instance_connect
```

Settings, to put in `~/.config/zsh/local.zsh`:

| Variable | Default | Meaning |
|---|---|---|
| `EC2_CONNECT_OS_USER` | `ubuntu` | Login user on the instance |
| `EC2_CONNECT_ADDRESS` | `private` | `private` or `public` IP address |
| `EC2_CONNECT_REGION` | region of the AWS profile | Region override |
| `EC2_CONNECT_PRIVATE_KEY` | `~/.ssh/ec2_instance_connect` | Local private key |
| `EC2_CONNECT_PUBLIC_KEY` | private key path + `.pub` | Local public key |
| `EC2_CONNECT_1PASSWORD_ITEM` | not set | 1Password item with the private key |
| `EC2_CONNECT_1PASSWORD_VAULT` | `Private` | Vault of that item |
| `EC2_CONNECT_1PASSWORD_FIELD` | `private key` | Field of that item |

## 7. Verify

In a new terminal window:

| Check | Command | Expected |
|---|---|---|
| Nothing left to install | `./install.sh --dry-run` | Only `unchanged` and `kept` rows, no warnings |
| Prompt and fonts | open iTerm2 | Oh My Posh prompt with icons |
| Fuzzy helpers | `fcd`, `ch`, Ctrl+R, Ctrl+T | fzf menus open |
| Tools | `brew bundle check --file=Brewfile` | Dependencies satisfied |
| SSH through 1Password | `ssh -T git@github.com` | 1Password prompt, then a greeting |
| Conda | `condaenv` | Environment menu |
| EC2 helpers | `type ec2_connect` | A shell function |

## 8. Keep the repo current

- **Shell, Git and app settings**: edit the file in the repo, then run `./install.sh --files-only`. Direct edits to an installed managed file are replaced on the next run (a backup is kept).
- **Software**: run `python3 scripts/inventory.py`. It compares Homebrew receipts, application bundles, common CLI paths, fonts, JDKs, plugins and Conda environments with the Brewfile and the inventory, and prints unlisted installs and declared items that are absent. Exit code 0 means no differences. The installer does not run this audit.
- **Adding software**: add it to the [Brewfile](Brewfile), or add a row (product, source, recovery action, discovery names) to the tab-separated [inventory](inventory/software.tsv). Entries you leave out on purpose go in the [exclusion list](inventory/exclude.txt).
- **Before committing**: the repo's pre-commit hooks scan for secrets and lint the scripts. See the [root README](../README.md#working-on-this-repo).

## 9. Reference

| Path | Purpose |
|---|---|
| [install.sh](install.sh) | The installer. |
| [Brewfile](Brewfile) | Homebrew formulae and casks. |
| [../lib/](../lib) | Helpers shared with the Linux installer: terminal output, file copy with backup, Git identity. |
| [scripts/inventory.py](scripts/inventory.py) | Software drift check. |
| [scripts/keyboard-remap.sh](scripts/keyboard-remap.sh) | Keyboard key swap (`keyboard-remap on|off|status`). |
| [config/keyboard/](config/keyboard) | LaunchAgent that reapplies the key swap at login. |
| [config/zsh/ec2.zsh](config/zsh/ec2.zsh) | EC2 Instance Connect helpers. |
| [config/ssh/config.example](config/ssh/config.example) | Starter SSH client config with examples. |
| [config/1password/agent.toml.example](config/1password/agent.toml.example) | Starter 1Password SSH agent key list. |
| [config/](config) | Everything else that is copied to the Mac, see section 1. |
| [inventory/](inventory) | Manually installed software and audit exclusions. |
