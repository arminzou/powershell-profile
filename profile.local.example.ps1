# Personal overrides for this machine/user.
# This file is loaded AFTER the repo profile, so definitions here take precedence.
#
# Suggested location:
#   $HOME\Documents\PowerShell\profile.local.ps1

# Example: override editor per machine
# $config.DefaultEditor = "notepad"

# Example: explicitly set Oh My Posh theme for this machine/user.
# This runs after the base profile and can override the default theme.
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\powerlevel10k_lean.omp.json" | Invoke-Expression

# Example: personal helper
# function hello-profile {
#     "Profile loaded on $env:COMPUTERNAME"
# }

# Example: fzf history on Ctrl+r
# if (Get-Command fzf -ErrorAction SilentlyContinue) {
#     Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
#         $historyPath = (Get-PSReadLineOption).HistorySavePath
#         if (Test-Path -Path $historyPath) {
#             $cmd = Get-Content $historyPath | Select-Object -Unique | fzf --tac
#             if ($cmd) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($cmd) }
#         }
#     }
# }
