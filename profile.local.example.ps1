# Personal overrides for this machine/user.
# This file is loaded AFTER the repo profile, so definitions here take precedence.
#
# Suggested location:
#   $HOME\Documents\PowerShell\profile.local.ps1

# Example: override editor per machine
# $config.DefaultEditor = "notepad"

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
