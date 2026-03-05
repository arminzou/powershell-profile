param()

$repoRoot = Split-Path -Path $PSCommandPath -Parent
$targetProfileDir = Split-Path -Path $PROFILE.CurrentUserAllHosts -Parent
if (-not (Test-Path -Path $targetProfileDir)) {
    New-Item -Path $targetProfileDir -ItemType Directory -Force | Out-Null
}

function Ensure-ProfileSymlink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        $isSymlink = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        $currentTarget = $null
        if ($isSymlink) {
            $currentTarget = ($item | Select-Object -ExpandProperty Target -ErrorAction SilentlyContinue)
        }

        if ($isSymlink -and $currentTarget -eq $Target) {
            Write-Host "Profile link already configured: $Path -> $Target" -ForegroundColor DarkGray
            return
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$Path.bak-$timestamp"
        Move-Item -LiteralPath $Path -Destination $backupPath -Force
        Write-Host "Backed up existing profile file to: $backupPath" -ForegroundColor Yellow
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
        Write-Host "Created profile symlink: $Path -> $Target" -ForegroundColor Green
    }
    catch {
        throw "Failed to create symlink at '$Path'. Enable Developer Mode or run elevated. Error: $($_.Exception.Message)"
    }
}

$modulesSource = Join-Path -Path $repoRoot -ChildPath "Modules"
$modulesTargetRoot = Join-Path -Path $targetProfileDir -ChildPath "Modules"
if (-not (Test-Path -Path $modulesTargetRoot)) {
    New-Item -Path $modulesTargetRoot -ItemType Directory -Force | Out-Null
}

if (Test-Path -Path $modulesSource -PathType Container) {
    Get-ChildItem -Path $modulesSource -Directory | ForEach-Object {
        $source = $_.FullName
        $target = Join-Path -Path $modulesTargetRoot -ChildPath $_.Name
        Ensure-ProfileSymlink -Path $target -Target $source
    }
}

$themesSource = Join-Path -Path $repoRoot -ChildPath "CustomThemes"
$themesTargetRoot = Join-Path -Path $targetProfileDir -ChildPath "CustomThemes"
if (-not (Test-Path -Path $themesTargetRoot)) {
    New-Item -Path $themesTargetRoot -ItemType Directory -Force | Out-Null
}

if (Test-Path -Path $themesSource -PathType Container) {
    Get-ChildItem -Path $themesSource -File | ForEach-Object {
        $source = $_.FullName
        $target = Join-Path -Path $themesTargetRoot -ChildPath $_.Name
        Ensure-ProfileSymlink -Path $target -Target $source
    }
}

Write-Host "Repo Modules/CustomThemes symlinks configured." -ForegroundColor Green
