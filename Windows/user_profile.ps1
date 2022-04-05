# Import oh-my-posh
Import-Module posh-git
Import-Module oh-my-posh

# Set Theme
Set-PoshPrompt sonicboom_dark

# Import Terminal-Icons
Import-Module -Name Terminal-Icons
Import-Module -Name Z

# PSReadLine
Set-PSReadLineOption -PredictionSource History

# Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'

# Alias
Set-Alias vim nvim
Set-Alias ll ls
Set-Alias grep findstr
#Set-Alias less 'D:\Git\usr\bin\less.exe'