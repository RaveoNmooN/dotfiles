# Import Modules
$modules = @('posh-git', 'Terminal-Icons', 'Z', 'PSFzf')
foreach ($module in $modules) {
    try {
        Import-Module $module -ErrorAction Stop
    } catch {
        Write-Warning "Could not import module: $module"
    }
}

# PSReadLine configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -EditMode Windows

# Set up PSReadLine key bindings for Fzf
if (Get-Module -Name PSFzf) {
    Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+f' -PSReadLineChordReverseHistory 'Ctrl+r'
}

# Aliases
$aliases = @{
    'vim'   = 'nvim'
    'll'    = 'ls'
    'grep'  = 'findstr'
    'g'     = 'git'
    'k'     = 'kubectl'
    'ls'    = 'Get-ChildItem'
    'cat'   = 'Get-Content'
    'rm'    = 'Remove-Item'
    'mv'    = 'Move-Item'
    'df'    = 'Get-PSDrive'
}
foreach ($alias in $aliases.GetEnumerator()) {
    Set-Alias -Name $alias.Key -Value $alias.Value
}

# Auto-completion for powershell
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

# Function that removes command/s from history based on match of a pattern
# Usage example: 
# Remove-CommandFromHistory "vault operator unseal"
function Remove-CommandFromHistory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$pattern
    )
    
    $historyPath = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path $historyPath) {
        $history = Get-Content $historyPath
        $filteredHistory = $history | Where-Object { $_ -notmatch $pattern }
        $filteredHistory | Set-Content $historyPath
    } else {
        Write-Warning "History file not found at: $historyPath"
    }
}

# Miniconda initialization
$condaPath = Join-Path $HOME "miniconda3\shell\condabin\conda-hook.ps1"
if (Test-Path $condaPath) {
    . $condaPath
} else {
    Write-Warning "Conda hook script not found at: $condaPath"
}

# Oh My Posh initialization
$localThemePath = Join-Path $HOME ".poshthemes\jandedobbeleer.omp.json"
if (Test-Path $localThemePath) {
    oh-my-posh init pwsh --config $localThemePath | Invoke-Expression
} else {
    Write-Warning "Oh My Posh theme file not found at: $localThemePath"
    $remoteThemePath = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/jandedobbeleer.omp.json"
    oh-my-posh init pwsh --config $remoteThemePath | Invoke-Expression
}

function Update-OhMyPoshTheme {
    param(
        [string]$Url = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/jandedobbeleer.omp.json",
        [string]$Destination = "$HOME\.poshthemes\jandedobbeleer.omp.json"
    )
    Invoke-WebRequest -Uri $Url -OutFile $Destination
    Write-Host "Theme updated at $Destination"
}