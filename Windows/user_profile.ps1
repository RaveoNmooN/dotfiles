# Changing the Prompt Shell View via oh-my-posh and Terminal-Icons module for PowerShell Core

oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/jandedobbeleer.omp.json' | Invoke-Expression

# Import Terminal-Icons and Z module
Import-Module -Name Terminal-Icons
Import-Module -Name Z

# PSReadLine settings
Set-PSReadLineOption -PredictionSource History

# Fzf settings
Import-Module PSFzf
Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'

# Alias for common commands and tools
Set-Alias vim nvim
Set-Alias ll ls
Set-Alias grep findstr
Set-Alias g git
Set-Alias k kubectl

# Auto-completion for powershell and kubectl
kubectl completion powershell | Out-String | Invoke-Expression

# Function that removes command/s from history based on match of a pattern if confidentioal commands were executed in the shell by mistake
# Usage example:
# Remove-CommandFromHistory "vault operator unseal"
function Remove-CommandFromHistory {
    param (
        [string]$pattern
    )

    # Remove from PSReadLine history
    $historyPath = (Get-PSReadlineOption).HistorySavePath
    $history = Get-Content $historyPath
    $filteredHistory = $history | Where-Object { $_ -notmatch $pattern }
    $filteredHistory | Set-Content $historyPath

    # Remove from current shell session history
    $history = Get-History
    $filteredHistory = $history | Where-Object { $_.CommandLine -notmatch $pattern }
    Clear-History
    $filteredHistory | Add-History
}
