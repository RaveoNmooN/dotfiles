# Installation steps for Powershell customization

## 1. Install a command-line installer for Windows - <https://scoop.sh/>, you can use winget, choro or any other package manager

```powershell
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

# or shorter
iwr -useb get.scoop.sh | iex
```

Note: if you get an error you might need to change the execution policy (i.e. enable Powershell) with

```powershell
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
```

## 2. Installation of usefull tools with scoop package manager

```powershell
scoop install curl sudo jq
scoop install neovim gcc
scoop update
```

## 3. Prerequisite for oh-my-posh is to install a Nerd Fonts - https://www.nerdfonts.com/

```powershell
The installation instructions are here https://github.com/ryanoasis/nerd-fonts
```

## 4. Install oh-my-posh - <https://ohmyposh.dev/>

```powershell
scoop install https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/oh-my-posh.json
```

Different posh themes can be found [here](https://ohmyposh.dev/docs/themes)

## 5. Install Terminal icons which will show icons for different file types in the terminal

```powershell
Install-Module -Name Terminal-Icons -Repository PSGallery --Force
Import-Module Terminal-Icons
```

The result should look similar to this

![ShellPrompt](https://i.imgur.com/kyUdG7c.png)

## 7. Install Z directory jumper for quick navigation between folders

```powershell
Install-Module -Name Z --Force
```

## 8. Install PSReadLine for typing autocompletion of recently used commands

```powershell
Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force -SkipPublisherCheck
Set-PSReadLineOption -PredictionSource History
```

## 9. Install Fuzzy finder

```powershell
scoop install fzf
Install-Module -Name PSFzf -Scope CurrentUser -Force
Import-Module PSFzf
```

and set the usage to be with Ctrl+f (for recursive folder search) and Ctrl+r (for history search)

```powershell
Set-PsFzfOption -PsReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'
```

So the final result should

![ShellPrompt](https://i.imgur.com/BY0iCmm.png)

## 10. Oh-my-posh can be customized a lot

Currently I am using default night-owl theme. If additional customization are needed you can follow the official guide [here](https://ohmyposh.dev/docs/config-overview)

## 11. Set User profile

The last step is to have all settings and module imports automatically loaded in your shell on startup. To achieve that, add the content of user_profile.ps1 file into your $PROFILE and customize it to your needs.

```powershell
code $PROFILE | Out-File -Append .\user_profile.ps1
```

You also can save it as a separate file and called it from your $PROFILE, adjust the full path to the file if you save it in a different location.

```powershell
code $PROFILE | Out-File -Append $env:USERPROFILE\.config\powershell\user_profile.ps1
```
