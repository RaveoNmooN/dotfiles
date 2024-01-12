# Changing the Prompt view
Import-Module posh-git
Import-Module oh-my-posh
Set-PoshPrompt jandedobbeleer

# Import Terminal-Icons
Import-Module -Name Terminal-Icons
Import-Module -Name Z

# PSReadLine
Set-PSReadLineOption -PredictionSource History

# Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'

# Alias for common commands
Set-Alias vim nvim
Set-Alias ll ls
Set-Alias grep findstr
Set-Alias g git
Set-Alias k kubectl

# Auto-completion for powershell
kubectl completion powershell | Out-String | Invoke-Expression

# Function that removes command/s from history based on match of a pattern
# Usage example: 
# Remove-CommandFromHistory "vault operator unseal"
function Remove-CommandFromHistory {
    param (
        [string]$pattern
    )

    $historyPath = (Get-PSReadlineOption).HistorySavePath
    $history = Get-Content $historyPath

    $filteredHistory = $history | Where-Object { $_ -notmatch $pattern }

    $filteredHistory | Set-Content $historyPath
}
