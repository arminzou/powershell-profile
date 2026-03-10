# PowerShell Profile

#region Configuration
# User configurable settings
$config = @{
    # General settings
    DefaultEditor         = "code"  # Set to a specific editor to override auto-detection
    ShowLoadTime          = $true  # Show profile load time
    
    # Update settings
    UpdateInterval        = 7      # Days between PowerShell update checks (-1 to always check)
    InstallMissingModules = $true  # Auto-install missing modules
    
    # UI settings
    DefaultTheme          = "jandedobbeleer"  # Default Oh-My-Posh theme if not set elsewhere
    EnablePredictions     = $true  # Enable PSReadLine predictions
    PredictionViewStyle   = "ListView" # Style for predictions
    MaxHistoryCount       = 10000  # Maximum number of commands to store in history
    
    # Custom paths
    CustomScriptsPath     = "$env:USERPROFILE\Documents\PowerShell\Scripts"  # Path to custom scripts
    ModulesPath           = "$env:USERPROFILE\Documents\PowerShell\Modules"  # Path to PowerShell modules
    
    # PSReadLine settings
    PSReadLine            = @{
        EditMode                      = "Windows"
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        Colors                        = @{
            Command   = "#87CEEB"  # SkyBlue (pastel)
            Parameter = "#98FB98"  # PaleGreen (pastel)
            Operator  = "#FFB6C1"  # LightPink (pastel)
            Variable  = "#DDA0DD"  # Plum (pastel)
            String    = "#FFDAB9"  # PeachPuff (pastel)
            Number    = "#B0E0E6"  # PowderBlue (pastel)
            Type      = "#F0E68C"  # Khaki (pastel)
            Comment   = "#D3D3D3"  # LightGray (pastel)
            Keyword   = "#8367c7"  # Violet (pastel)
            Error     = "#FF6347"  # Tomato (keeping it close to red for visibility)
        }
    }
    
    # Module settings
    ModulesToLoad         = @(
        "FileManagement",
        "GitAliases",
        "NetworkTools",
        "SystemUtilities",
        "Productivity"
    )
}

# Check if required directories exist
foreach ($path in @($config.CustomScriptsPath, $config.ModulesPath)) {
    if (-not (Test-Path $path)) {
        Write-Warning "Required directory not found: $path."
    }
}
#endregion Configuration

# Create modules directory if it doesn't exist
if (-not (Test-Path $config.ModulesPath)) {
    New-Item -ItemType Directory -Path $config.ModulesPath -Force | Out-Null
    Write-Host "Created modules directory at $($config.ModulesPath)" -ForegroundColor Cyan
}

# Ensure scripts directory exists for state files (e.g., LastExecutionTime.txt)
if (-not (Test-Path $config.CustomScriptsPath)) {
    New-Item -ItemType Directory -Path $config.CustomScriptsPath -Force | Out-Null
}

# Prefer repo-local modules when this profile is executed from the repo.
$repoModulesPath = Join-Path $PSScriptRoot "Modules"
$moduleSearchRoots = @($repoModulesPath, $config.ModulesPath) | Select-Object -Unique

# Load modules if they exist and aren't already loaded
$config.ModulesToLoad | ForEach-Object {
    $moduleName = $_
    
    # Check if module is already loaded
    if (-not (Get-Module -Name $moduleName)) {
        $modulePath = $moduleSearchRoots |
        ForEach-Object { Join-Path $_ $moduleName } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

        if ($modulePath) {
            try {
                Import-Module $modulePath -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to load module '$moduleName': $_"
            }
        }
        else {
            Write-Warning "Module '$moduleName' not found in: $($moduleSearchRoots -join ', ')"
        }
    }
}

# Define the path to the file that stores the last execution time
$timeFilePath = Join-Path $config.CustomScriptsPath "LastExecutionTime.txt"

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Initial GitHub.com connectivity check with 1 second timeout
$global:canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

# Import Terminal-Icons Module
if (-not (Get-Module -Name Terminal-Icons)) {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module -Name Terminal-Icons
    }
    else {
        Write-Verbose "Terminal-Icons is not installed. Run setup.ps1 to install dependencies."
    }
}

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Check for PowerShell updates based on configured interval
$shouldCheckPowerShellUpdate = $false
if ($config.UpdateInterval -eq -1 -or -not (Test-Path $timeFilePath)) {
    $shouldCheckPowerShellUpdate = $true
}
else {
    try {
        $lastCheck = [datetime]::ParseExact((Get-Content -Path $timeFilePath -Raw).Trim(), 'yyyy-MM-dd', $null)
        $shouldCheckPowerShellUpdate = ((Get-Date).Date - $lastCheck.Date).TotalDays -gt $config.UpdateInterval
    }
    catch {
        $shouldCheckPowerShellUpdate = $true
    }
}

if ($shouldCheckPowerShellUpdate) {
    Update-PowerShell
    $currentTime = Get-Date -Format 'yyyy-MM-dd'
    $currentTime | Out-File -FilePath $timeFilePath
}

# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode                      = $config.PSReadLine.EditMode
    HistoryNoDuplicates           = $config.PSReadLine.HistoryNoDuplicates
    HistorySearchCursorMovesToEnd = $config.PSReadLine.HistorySearchCursorMovesToEnd
    Colors                        = $config.PSReadLine.Colors
    PredictionSource              = 'None'
    PredictionViewStyle           = $config.PredictionViewStyle
    BellStyle                     = 'None'
}
try {
    $supportsPredictions = $false
    if ($config.EnablePredictions) {
        $supportsPredictions = [bool]$Host.UI.SupportsVirtualTerminal
    }
    if ($supportsPredictions) {
        $PSReadLineOptions.PredictionSource = 'HistoryAndPlugin'
    }
    Set-PSReadLineOption @PSReadLineOptions
}
catch {
    Write-Verbose "PSReadLine advanced configuration skipped: $($_.Exception.Message)"
}

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Improved prediction settings
if ($config.EnablePredictions -and [bool]$Host.UI.SupportsVirtualTerminal) {
    try {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }
    catch {
        Write-Verbose "PredictionSource configuration skipped: $($_.Exception.Message)"
    }
}
Set-PSReadLineOption -MaximumHistoryCount $config.MaxHistoryCount

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm'  = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }
    
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock


# Get theme from profile.ps1 or use a default theme
function Get-Theme {

    $themeFileName = "$($config.DefaultTheme).omp.json"
    $localThemeRoots = @(
        (Join-Path $PSScriptRoot "CustomThemes"),
        (Join-Path "$env:USERPROFILE\Documents\PowerShell" "CustomThemes")
    ) | Select-Object -Unique
    $officialThemeRoots = @(
        $env:POSH_THEMES_PATH,
        (Join-Path "$env:USERPROFILE\AppData\Local\Programs\oh-my-posh\themes" ""),
        (Join-Path "$env:LOCALAPPDATA\Programs\oh-my-posh\themes" "")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    $localThemePath = $localThemeRoots |
    ForEach-Object { Join-Path $_ $themeFileName } |
    Where-Object { Test-Path $_ -PathType Leaf } |
    Select-Object -First 1

    if ($localThemePath) {
        oh-my-posh init pwsh --config $localThemePath | Invoke-Expression
        return
    }

    $officialThemePath = $officialThemeRoots |
    ForEach-Object { Join-Path $_ $themeFileName } |
    Where-Object { Test-Path $_ -PathType Leaf } |
    Select-Object -First 1

    if ($officialThemePath) {
        oh-my-posh init pwsh --config $officialThemePath | Invoke-Expression
        return
    }

    $officialThemeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$themeFileName"
    try {
        $response = Invoke-WebRequest -Uri $officialThemeUrl -UseBasicParsing -Method Head -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            oh-my-posh init pwsh --config $officialThemeUrl | Invoke-Expression
            return
        }
    }
    catch {
        # No warning here; we warn once below if neither source has the theme.
    }

    Write-Warning "Theme '$themeFileName' was not found in local CustomThemes or official Oh My Posh themes."
}

## Final Line to set prompt
Get-Theme
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
else {
    Write-Verbose "zoxide command not found. Run setup.ps1 to install it."
}

Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force

# PowerShell 7 specific function for parallel processing
function Invoke-ParallelCommand {
    <#
    .SYNOPSIS
        Runs commands in parallel using PowerShell 7's ForEach-Object -Parallel
        
    .DESCRIPTION
        Executes commands in parallel across multiple threads
        
    .PARAMETER Command
        The scriptblock to execute for each input object
        
    .PARAMETER InputObject
        The objects to process in parallel
        
    .PARAMETER ThrottleLimit
        Maximum number of concurrent threads (default: 5)
        
    .EXAMPLE
        1..10 | Invoke-ParallelCommand { Start-Sleep -Seconds $_; "Slept for $_ seconds" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [scriptblock]$Command,
        
        [Parameter(ValueFromPipeline = $true)]
        [object[]]$InputObject,
        
        [Parameter()]
        [int]$ThrottleLimit = 5
    )
    
    begin {
        $objects = @()
        
        # Check if running in PowerShell 7+
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Warning "This function requires PowerShell 7 or later for parallel processing."
            return
        }
    }
    
    process {
        # Collect all input objects
        foreach ($obj in $InputObject) {
            $objects += $obj
        }
    }
    
    end {
        # Process objects in parallel
        $objects | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel $Command
    }
}

# Opens the Windows Recycle Bin in File Explorer
function Open-RecycleBin {
    Start-Process "shell:RecycleBinFolder"
}

# Quick Access to Editing the Profile
function Edit-Profile {
    $editor = $config.DefaultEditor
    
    if ($null -eq $editor) {
        # Auto-detect common editors
        if (Get-Command code -ErrorAction SilentlyContinue) {
            $editor = "code"
        }
        elseif (Get-Command notepad -ErrorAction SilentlyContinue) {
            $editor = "notepad"
        }
        elseif (Get-Command vim -ErrorAction SilentlyContinue) {
            $editor = "vim"
        }
        else {
            Write-Error "No suitable editor found. Please set DefaultEditor in your profile configuration."
            return
        }
    }
    
    & $editor $PROFILE.CurrentUserAllHosts
}
Set-Alias -Name ep -Value Edit-Profile

# Quick Reload the Profile
function Update-Profile {
    . $profile
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Locate the full path of an executable file associated
function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

# Export a variable to the environment
function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

# Kill processes by name
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

# Get processes by name
function pgrep($name) {
    Get-Process $name
}

# Help Function
function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)

$($PSStyle.Foreground.Magenta)SYSTEM MANAGEMENT$($PSStyle.Reset)
-------------------
$($PSStyle.Foreground.Green)Update-PowerShell$($PSStyle.Reset) - Checks for the latest PowerShell release and updates if a new version is available.
$($PSStyle.Foreground.Green)Clear-Cache$($PSStyle.Reset) - Clears various Windows caches.
$($PSStyle.Foreground.Green)sysinfo$($PSStyle.Reset) - Displays detailed system information.
$($PSStyle.Foreground.Green)uptime$($PSStyle.Reset) - Displays the system uptime.
$($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Clears the DNS cache.
$($PSStyle.Foreground.Green)admin$($PSStyle.Reset) [command] - Runs a command with elevated privileges.
$($PSStyle.Foreground.Green)su$($PSStyle.Reset) [command] - Alias for admin.

$($PSStyle.Foreground.Magenta)PROFILE MANAGEMENT$($PSStyle.Reset)
-------------------
$($PSStyle.Foreground.Green)Edit-Profile$($PSStyle.Reset) - Opens the current user's profile for editing using the configured editor.
$($PSStyle.Foreground.Green)Update-Profile$($PSStyle.Reset) - Reloads the current user's PowerShell profile.

$($PSStyle.Foreground.Magenta)FILE MANAGEMENT$($PSStyle.Reset)
---------------
$($PSStyle.Foreground.Green)touch$($PSStyle.Reset) <file> - Creates a new empty file.
$($PSStyle.Foreground.Green)ff$($PSStyle.Reset) <name> - Finds files recursively with the specified name.
$($PSStyle.Foreground.Green)unzip$($PSStyle.Reset) <file> - Extracts a zip file to the current directory.
$($PSStyle.Foreground.Green)grep$($PSStyle.Reset) <regex> [dir] - Searches for a pattern in files.
$($PSStyle.Foreground.Green)sed$($PSStyle.Reset) <file> <find> <replace> - Replaces text in a file.
$($PSStyle.Foreground.Green)head$($PSStyle.Reset) <path> [n] - Displays the first n lines of a file (default 10).
$($PSStyle.Foreground.Green)tail$($PSStyle.Reset) <path> [n] - Displays the last n lines of a file (default 10).
$($PSStyle.Foreground.Green)nf$($PSStyle.Reset) <name> - Creates a new file with the specified name.
$($PSStyle.Foreground.Green)mkcd$($PSStyle.Reset) <dir> - Creates and changes to a new directory.
$($PSStyle.Foreground.Green)trash$($PSStyle.Reset) <path> - Moves a file or directory to the recycle bin.

$($PSStyle.Foreground.Magenta)NAVIGATION$($PSStyle.Reset)
----------
$($PSStyle.Foreground.Green)docs$($PSStyle.Reset) - Changes to the Documents folder.
$($PSStyle.Foreground.Green)dtop$($PSStyle.Reset) - Changes to the Desktop folder.
$($PSStyle.Foreground.Green)z$($PSStyle.Reset) <dir> - Jumps to a frequently used directory (requires zoxide).
$($PSStyle.Foreground.Green)zi$($PSStyle.Reset) - Interactive selection of directories (requires zoxide).

$($PSStyle.Foreground.Magenta)GIT SHORTCUTS$($PSStyle.Reset)
-------------
$($PSStyle.Foreground.Green)gs$($PSStyle.Reset) - Shows git status.
$($PSStyle.Foreground.Green)ga$($PSStyle.Reset) - Adds all changes to git.
$($PSStyle.Foreground.Green)gc$($PSStyle.Reset) <message> - Commits with a message.
$($PSStyle.Foreground.Green)gp$($PSStyle.Reset) - Pushes to the remote repository.
$($PSStyle.Foreground.Green)g$($PSStyle.Reset) - Changes to the GitHub directory.
$($PSStyle.Foreground.Green)gcl$($PSStyle.Reset) <repo> - Clones a git repository.
$($PSStyle.Foreground.Green)gcom$($PSStyle.Reset) <message> - Adds and commits with a message.
$($PSStyle.Foreground.Green)lazyg$($PSStyle.Reset) <message> - Adds, commits, and pushes with a message.

$($PSStyle.Foreground.Magenta)POWERSHELL 7 FEATURES$($PSStyle.Reset)
---------------------
$($PSStyle.Foreground.Green)Invoke-ParallelCommand$($PSStyle.Reset) - Runs commands in parallel.

$($PSStyle.Foreground.Magenta)UTILITIES$($PSStyle.Reset)
---------
$($PSStyle.Foreground.Green)which$($PSStyle.Reset) <name> - Shows the path of a command.
$($PSStyle.Foreground.Green)export$($PSStyle.Reset) <name> <value> - Sets an environment variable.
$($PSStyle.Foreground.Green)pkill$($PSStyle.Reset) <name> - Kills processes by name.
$($PSStyle.Foreground.Green)pgrep$($PSStyle.Reset) <name> - Lists processes by name.
$($PSStyle.Foreground.Green)df$($PSStyle.Reset) - Shows volume information.
$($PSStyle.Foreground.Green)Get-PubIP$($PSStyle.Reset) - Shows your public IP address.
$($PSStyle.Foreground.Green)winutil$($PSStyle.Reset) - Launches Chris Titus Tech's Windows utility.
$($PSStyle.Foreground.Green)cpy$($PSStyle.Reset) <text> - Copies text to clipboard.
$($PSStyle.Foreground.Green)pst$($PSStyle.Reset) - Pastes from clipboard.

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' to display this help message.
"@
    Write-Host $helpText
}

# Load machine/user-specific overrides after base profile setup.
$localOverride = Join-Path -Path $HOME -ChildPath "Documents\PowerShell\profile.local.ps1"
if (Test-Path -Path $localOverride -PathType Leaf) {
    . $localOverride
}

Write-Host "$($PSStyle.Foreground.Yellow)Use 'Show-Help' to display help$($PSStyle.Reset)"
