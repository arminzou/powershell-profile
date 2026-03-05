# Test script for verifying PowerShell profile setup (symlink model)
[CmdletBinding()]
param()

Write-Host "===== PowerShell Profile Setup Test =====" -ForegroundColor Cyan

$testResults = @{}

function Update-TestResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component,
        [Parameter(Mandatory = $true)]
        [bool]$Success,
        [string]$Details = ""
    )

    $testResults[$Component] = @{
        Success = $Success
        Details = $Details
    }

    if ($Success) {
        Write-Host "  [PASS] $Component" -ForegroundColor Green
    }
    else {
        Write-Host "  [FAIL] $Component" -ForegroundColor Red
    }

    if ($Details) {
        Write-Host "     $Details" -ForegroundColor Gray
    }
}

function Test-SymlinkTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedTarget
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ Success = $false; Details = "Path not found: $Path" }
    }

    $item = Get-Item -LiteralPath $Path -Force
    $isLink = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    if (-not $isLink) {
        return @{ Success = $false; Details = "Not a symlink: $Path" }
    }

    $target = $item.Target
    if ($target -eq $ExpectedTarget) {
        return @{ Success = $true; Details = "Symlink OK: $Path -> $target" }
    }

    return @{ Success = $false; Details = "Symlink target mismatch. Expected: $ExpectedTarget, Actual: $target" }
}

$profileDir = Split-Path -Path $PROFILE.CurrentUserAllHosts -Parent
$repoRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoProfile = Join-Path -Path $repoRoot -ChildPath "Microsoft.PowerShell_profile.ps1"
$hostProfile = $PROFILE.CurrentUserCurrentHost
$allHostsProfile = $PROFILE.CurrentUserAllHosts
$localOverride = Join-Path -Path $profileDir -ChildPath "profile.local.ps1"

Write-Host "`nTesting profile symlink..." -ForegroundColor Yellow
if (Test-Path -Path $repoProfile -PathType Leaf) {
    $result = Test-SymlinkTarget -Path $hostProfile -ExpectedTarget $repoProfile
    Update-TestResult -Component "Host Profile Symlink" -Success $result.Success -Details $result.Details
}
else {
    Update-TestResult -Component "Host Profile Symlink" -Success $false -Details "Repo profile not found at: $repoProfile"
}

Write-Host "`nTesting AllHosts profile behavior..." -ForegroundColor Yellow
if (Test-Path -LiteralPath $allHostsProfile) {
    $allHostsItem = Get-Item -LiteralPath $allHostsProfile -Force
    $allHostsIsLink = ($allHostsItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    if ($allHostsIsLink -and $allHostsItem.Target -eq $repoProfile) {
        Update-TestResult -Component "AllHosts Profile" -Success $false -Details "AllHosts profile points to repo profile and may cause duplicate loading."
    }
    else {
        Update-TestResult -Component "AllHosts Profile" -Success $true -Details "AllHosts profile does not duplicate host profile symlink."
    }
}
else {
    Update-TestResult -Component "AllHosts Profile" -Success $true -Details "AllHosts profile file not present (acceptable): $allHostsProfile"
}

Write-Host "`nTesting local override profile..." -ForegroundColor Yellow
if (Test-Path -Path $localOverride -PathType Leaf) {
    Update-TestResult -Component "Local Override Profile" -Success $true -Details "Found: $localOverride"
}
else {
    Update-TestResult -Component "Local Override Profile" -Success $false -Details "Missing: $localOverride"
}

Write-Host "`nTesting module symlinks..." -ForegroundColor Yellow
$moduleNames = @("FileManagement", "GitAliases", "NetworkTools", "SystemUtilities", "Productivity")
$modulesRoot = Join-Path -Path $profileDir -ChildPath "Modules"
$allModulesOk = $true
$moduleDetails = @()

foreach ($moduleName in $moduleNames) {
    $targetPath = Join-Path -Path $modulesRoot -ChildPath $moduleName
    $sourcePath = Join-Path -Path (Join-Path -Path $repoRoot -ChildPath "Modules") -ChildPath $moduleName
    $res = Test-SymlinkTarget -Path $targetPath -ExpectedTarget $sourcePath
    if (-not $res.Success) { $allModulesOk = $false }
    $moduleDetails += "${moduleName}: $($res.Success)"
}

Update-TestResult -Component "Module Symlinks" -Success $allModulesOk -Details ($moduleDetails -join ", ")

Write-Host "`nTesting custom theme symlinks..." -ForegroundColor Yellow
$themesSource = Join-Path -Path $repoRoot -ChildPath "CustomThemes"
$themesTarget = Join-Path -Path $profileDir -ChildPath "CustomThemes"
$themesOk = $true
$themeDetails = @()

if (Test-Path -Path $themesSource -PathType Container) {
    Get-ChildItem -Path $themesSource -File | ForEach-Object {
        $source = $_.FullName
        $target = Join-Path -Path $themesTarget -ChildPath $_.Name
        $res = Test-SymlinkTarget -Path $target -ExpectedTarget $source
        if (-not $res.Success) { $themesOk = $false }
        $themeDetails += "$($_.Name): $($res.Success)"
    }
    Update-TestResult -Component "Theme Symlinks" -Success $themesOk -Details ($themeDetails -join ", ")
}
else {
    Update-TestResult -Component "Theme Symlinks" -Success $false -Details "Source themes directory not found: $themesSource"
}

Write-Host "`nTesting dependencies..." -ForegroundColor Yellow
try {
    $omp = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    Update-TestResult -Component "Oh My Posh" -Success ([bool]$omp) -Details ($(if ($omp) { & oh-my-posh --version } else { "Not found in PATH" }))
}
catch {
    Update-TestResult -Component "Oh My Posh" -Success $false -Details "Error: $_"
}

try {
    $terminalIcons = Get-Module -ListAvailable -Name Terminal-Icons
    Update-TestResult -Component "Terminal-Icons" -Success ([bool]$terminalIcons) -Details ($(if ($terminalIcons) { "Version: $($terminalIcons.Version)" } else { "Module not found" }))
}
catch {
    Update-TestResult -Component "Terminal-Icons" -Success $false -Details "Error: $_"
}

try {
    $zoxide = Get-Command zoxide -ErrorAction SilentlyContinue
    Update-TestResult -Component "zoxide" -Success ([bool]$zoxide) -Details ($(if ($zoxide) { & zoxide --version } else { "Not found in PATH" }))
}
catch {
    Update-TestResult -Component "zoxide" -Success $false -Details "Error: $_"
}

$passedTests = ($testResults.Values | Where-Object { $_.Success -eq $true }).Count
$totalTests = $testResults.Count

Write-Host "`n===== Summary =====" -ForegroundColor Cyan
Write-Host "Passed $passedTests out of $totalTests tests" -ForegroundColor Cyan

if ($passedTests -lt $totalTests) {
    Write-Host "`n===== Recommendations for Failed Tests =====" -ForegroundColor Yellow
    foreach ($component in $testResults.Keys) {
        if (-not $testResults[$component].Success) {
            Write-Host "Component: $component" -ForegroundColor Red
            switch ($component) {
                "Host Profile Symlink" {
                    Write-Host "  - Run .\\setprofile.ps1 from the repo root." -ForegroundColor Yellow
                }
                "AllHosts Profile" {
                    Write-Host "  - Ensure profile.ps1 is not symlinked to the same repo profile as host profile." -ForegroundColor Yellow
                }
                "Local Override Profile" {
                    Write-Host "  - Create $localOverride (or re-run .\\setprofile.ps1)." -ForegroundColor Yellow
                }
                "Module Symlinks" {
                    Write-Host "  - Re-run .\\setprofile.ps1 to recreate module links." -ForegroundColor Yellow
                }
                "Theme Symlinks" {
                    Write-Host "  - Re-run .\\setprofile.ps1 to recreate theme links." -ForegroundColor Yellow
                }
                "Oh My Posh" {
                    Write-Host "  - Install with: winget install -e --id JanDeDobbeleer.OhMyPosh" -ForegroundColor Yellow
                }
                "Terminal-Icons" {
                    Write-Host "  - Install with: Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force" -ForegroundColor Yellow
                }
                "zoxide" {
                    Write-Host "  - Install with: winget install -e --id ajeetdsouza.zoxide" -ForegroundColor Yellow
                }
            }
        }
    }
}

Write-Host "`n===== End of Test =====" -ForegroundColor Cyan
