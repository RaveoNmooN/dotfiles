# Installation steps for Powershell customization

## 1. Install a command-line installer for Windows - https://scoop.sh/
```
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

# or shorter
iwr -useb get.scoop.sh | iex
```

Note: if you get an error you might need to change the execution policy (i.e. enable Powershell) with

```
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
```


## 2. Install tools with scoop

```
scoop install curl sudo jq
scoop install neovim gcc
scoop update
```


## 3. Prerequisite for oh-my-posh is to install a Nerd Fonts - https://www.nerdfonts.com/
```
The installation instructions are here https://github.com/ryanoasis/nerd-fonts
```


## 4. Now install modules which will improve PowerShell prompt
Provides prompt with Git status summary information and tab completion for Git commands, parameters, remotes and branch names.

```
Install-Module posh-git -Scope CurrentUser -Force
```

To import module run in current session
```
Import-Module posh-git
```

Modules can be imported automatically on shell startup when the needed settings are put in
user $PROFILE. This is where user_profile.ps1 file comes, all neccessery settings are inside of it.


## 5. Install oh-my-posh - https://ohmyposh.dev/
```
Install-Module oh-my-posh -Scope CurrentUser -Force
Import-Module oh-my-posh
Set-PoshPromt -Theme <THEME_NAME>
```
Different posh themes can be found [here](https://ohmyposh.dev/docs/themes)


## 6. Install Terminal icons which will display icons of all folder and files in the shell
```
Install-Module -Name Terminal-Icons -Repository PSGallery -Force
Import-Module Terminal-Icons
```

The result should look similar to this

![ShellPrompt](https://i.imgur.com/kyUdG7c.png)


## 7. Install Z directory jumper

```
Install-Module -Name Z -Force
```

## 8. Install PSReadLine for typing autocompletion of recently used commands
```
Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force -SkipPublisherCheck
Set-PSReadLineOption -PredictionSource History
```

## 9. Install Fuzzy finder
```
scoop install fzf
Install-Module -Name PSFzf -Scope CurrentUser -Force
Import-Module PSFzf
```

and set the usage to be with Ctrl+f (for recursive folder search) and Ctrl+r (for history search)
```
Set-PsFzfOption -PsReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'
```

So the final result should

![ShellPrompt](https://i.imgur.com/BY0iCmm.png)

## 10. Oh-my-posh can be customized a lot
Currently I am using default night-owl theme. If additional customization are needed you can follow the official guide [here](https://ohmyposh.dev/docs/config-overview)


## 11. Set User profile
The last step is to have all settings and module imports automatically adjusted in your shell on startup. To achieve that, add the file user_profile.ps1 into your $PROFILE

For example, if you are using VS Code you can run

```
code $PROFILE - this will open your $PROFILE file directly in VS Code
```
and set the following line using the full path for your user_profile.ps1 file

```
$env:USERPROFILE\.config\powershell\user_profile.ps1
```