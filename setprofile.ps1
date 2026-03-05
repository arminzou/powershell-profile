param()

$repoRoot = Split-Path -Path $PSCommandPath -Parent
$repoProfile = Join-Path -Path $repoRoot -ChildPath "Microsoft.PowerShell_profile.ps1"
if (-not (Test-Path -Path $repoProfile -PathType Leaf)) {
    throw "Repo profile not found at: $repoProfile"
}

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

$targetProfile = $PROFILE.CurrentUserCurrentHost
Ensure-ProfileSymlink -Path $targetProfile -Target $repoProfile

# Avoid duplicate loading: if CurrentUserAllHosts points to the same repo profile, replace it with a no-op file.
$allHostsProfile = $PROFILE.CurrentUserAllHosts
if (Test-Path -LiteralPath $allHostsProfile) {
    $allHostsItem = Get-Item -LiteralPath $allHostsProfile -Force
    $isAllHostsSymlink = ($allHostsItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    $allHostsTarget = $null
    if ($isAllHostsSymlink) {
        $allHostsTarget = ($allHostsItem | Select-Object -ExpandProperty Target -ErrorAction SilentlyContinue)
    }

    if ($isAllHostsSymlink -and $allHostsTarget -eq $repoProfile) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$allHostsProfile.bak-$timestamp"
        Move-Item -LiteralPath $allHostsProfile -Destination $backupPath -Force
        Set-Content -Path $allHostsProfile -Value "# Intentionally left minimal by setprofile.ps1 to avoid duplicate profile loading." -Encoding utf8
        Write-Host "Replaced duplicate AllHosts symlink with a minimal file: $allHostsProfile" -ForegroundColor Yellow
    }
}

$localOverride = Join-Path -Path $targetProfileDir -ChildPath "profile.local.ps1"
$localTemplate = Join-Path -Path $repoRoot -ChildPath "profile.local.example.ps1"
if ((-not (Test-Path -Path $localOverride -PathType Leaf)) -and (Test-Path -Path $localTemplate -PathType Leaf)) {
    Copy-Item -Path $localTemplate -Destination $localOverride -Force
    Write-Host "Created local override file from template: $localOverride" -ForegroundColor Green
}
