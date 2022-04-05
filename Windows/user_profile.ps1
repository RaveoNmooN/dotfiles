# Import oh-my-posh
Import-Module posh-git
Import-Module oh-my-posh

# Set Theme
Set-PoshPrompt night-owl

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
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'