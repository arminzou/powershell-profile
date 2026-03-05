# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    exit 1
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        Invoke-WebRequest -Uri "https://github.com" -Method Head -TimeoutSec 5 | Out-Null
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}

function Backup-FileIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BackupPath
    )

    if (Test-Path -Path $Path -PathType Leaf) {
        Move-Item -Path $Path -Destination $BackupPath -Force
    }
}

function Save-ProfileFromBestSource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $localRepoProfile = Join-Path -Path $PSScriptRoot -ChildPath "Microsoft.PowerShell_profile.ps1"
    if (Test-Path -Path $localRepoProfile -PathType Leaf) {
        Copy-Item -Path $localRepoProfile -Destination $DestinationPath -Force
        return
    }

    $candidateUrls = @(
        "https://raw.githubusercontent.com/arminzou/PowerShell-Profile/main/Microsoft.PowerShell_profile.ps1",
        "https://raw.githubusercontent.com/arminzou/PowerShell-Profile/master/Microsoft.PowerShell_profile.ps1"
    )

    foreach ($url in $candidateUrls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $DestinationPath -UseBasicParsing
            return
        }
        catch {
            # Try next URL candidate.
        }
    }

    throw "Failed to download profile from repository."
}

# Function to install Nerd Fonts
function Install-NerdFonts {
    param (
        [string]$FontName = "CascadiaCode",
        [string]$FontDisplayName = "CaskaydiaCove NF",
        [string]$Version = "3.2.1"
    )

    try {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        $fontsDir = Join-Path $env:WINDIR "Fonts"
        $normalizedDisplayName = ($FontDisplayName -replace '\s', '')
        $normalizedFontName = ($FontName -replace '\s', '')
        $fontFilesExist = @(
            "$normalizedFontName*.ttf",
            "$normalizedDisplayName*.ttf"
        ) | ForEach-Object { Get-ChildItem -Path $fontsDir -Filter $_ -ErrorAction SilentlyContinue } | Select-Object -First 1

        $familyExists = ($fontFamilies -contains $FontDisplayName) -or ($fontFamilies -like "$FontDisplayName*")
        if (-not $familyExists -and -not $fontFilesExist) {
            Write-Host "Downloading and installing ${FontDisplayName} font..."
            $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${Version}/${FontName}.zip"
            $zipFilePath = "$env:TEMP\${FontName}.zip"
            $extractPath = "$env:TEMP\${FontName}"

            # Use more reliable download method
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing
            }
            catch {
                # Fallback to WebClient if Invoke-WebRequest fails
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($fontZipUrl, $zipFilePath)
            }

            if (Test-Path $zipFilePath) {
                Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force
                $destination = (New-Object -ComObject Shell.Application).Namespace(0x14)
                Get-ChildItem -Path $extractPath -Recurse -Filter "*.ttf" | ForEach-Object {
                    If (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
                        $destination.CopyHere($_.FullName, 0x10)
                    }
                }

                Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue
                Write-Host "${FontDisplayName} font installed successfully."
            }
            else {
                throw "Failed to download font zip file."
            }
        }
        else {
            Write-Host "Font ${FontDisplayName} already installed. Skipping installation."
        }
        return $true
    }
    catch {
        Write-Error "Failed to download or install ${FontDisplayName} font. Error: $_"
        return $false
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    exit 1
}

# Initialize success tracking
$successCount = 0
$totalSteps = 6  # Profile, OMP, Font, Choco, Terminal-Icons, Zoxide

# Profile creation or update
$profileSuccess = $false

# Detect Version of PowerShell & Create Profile directories if they do not exist.
$profilePath = ""
if ($PSVersionTable.PSEdition -eq "Core") {
    $profilePath = "$env:userprofile\Documents\Powershell"
}
elseif ($PSVersionTable.PSEdition -eq "Desktop") {
    $profilePath = "$env:userprofile\Documents\WindowsPowerShell"
}

if (!(Test-Path -Path $profilePath)) {
    New-Item -Path $profilePath -ItemType "directory" | Out-Null
}

try {
    $profileExists = Test-Path -Path $PROFILE -PathType Leaf
    $mainBackupPath = Join-Path $profilePath "oldprofile.ps1"
    $vscodeProfilePath = Join-Path $profilePath "Microsoft.VSCode_profile.ps1"
    $vscodeBackupPath = Join-Path $profilePath "oldvscodeprofile.ps1"

    if ($profileExists) {
        Write-Host "Profile found, backing up and updating profile..."
        Backup-FileIfExists -Path $PROFILE -BackupPath $mainBackupPath
    }
    else {
        Write-Host "Profile not found, creating profile..."
    }

    Save-ProfileFromBestSource -DestinationPath $PROFILE
    Write-Host "The profile @ [$PROFILE] has been created."
    if ($profileExists) {
        Write-Host "Old profile backed up to [$mainBackupPath]"
    }
    Write-Host "Put personal customizations in [$profilePath\profile.local.ps1]"

    Backup-FileIfExists -Path $vscodeProfilePath -BackupPath $vscodeBackupPath
    Copy-Item -Path $PROFILE -Destination $vscodeProfilePath -Force
    if (Test-Path -Path $vscodeBackupPath -PathType Leaf) {
        Write-Host "The VS Code profile @ [$vscodeProfilePath] has been updated and old profile backed up to [$vscodeBackupPath]"
    }
    else {
        Write-Host "The VS Code profile @ [$vscodeProfilePath] has been created."
    }

    $profileSuccess = $true
    $successCount++
}
catch {
    Write-Error "Failed to create or update the profile. Error: $_"
}

# OMP Install
$ompSuccess = $false
try {
    Write-Host "Checking for Oh My Posh installation..."
    
    # Check if oh-my-posh command exists and get its version
    $ompCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($ompCommand) {
        $currentVersion = (oh-my-posh version).Trim()
        Write-Host "Oh My Posh version $currentVersion is installed."
        
        # Check for updates if installed via winget
        try {
            $wingetCheck = winget list --id JanDeDobbeleer.OhMyPosh -e
            if ($wingetCheck -match "Oh My Posh") {
                Write-Host "Checking for Oh My Posh updates..."
                winget upgrade -e --id JanDeDobbeleer.OhMyPosh --accept-source-agreements
            }
        }
        catch {
            Write-Host "Oh My Posh was installed via alternative method, skipping winget update check."
        }
        
        $ompSuccess = $true
        $successCount++
    }
    else {
        Write-Host "Oh My Posh not found. Installing via winget..."
        
        # Try to install via winget
        try {
            winget install -e --accept-source-agreements --accept-package-agreements JanDeDobbeleer.OhMyPosh
            
            # Verify installation
            if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
                $version = (oh-my-posh version).Trim()
                Write-Host "Oh My Posh version $version installed successfully."
                $ompSuccess = $true
                $successCount++
            }
            else {
                throw "Oh My Posh installation verification failed."
            }
        }
        catch {
            Write-Error "Failed to install Oh My Posh via winget. Error: $_"
        }
    }
}
catch {
    Write-Error "Failed to process Oh My Posh installation. Error: $_"
}

# Font Install
$fontSuccess = Install-NerdFonts -FontName "CascadiaCode" -FontDisplayName "CaskaydiaCove NF"
if ($fontSuccess) {
    $successCount++
}

# Choco install
$chocoSuccess = $false
try {
    # Check if Chocolatey is already installed
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey is already installed. Checking for updates..."
        choco upgrade chocolatey -y
        $chocoSuccess = $true
        $successCount++
    }
    else {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Installing Chocolatey via winget..."
            winget install -e --id Chocolatey.Chocolatey --accept-source-agreements --accept-package-agreements
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                $chocoSuccess = $true
                $successCount++
            }
            else {
                throw "Chocolatey installation verification failed."
            }
        }
        else {
            Write-Warning "Winget not found. Skipping Chocolatey auto-install for safety."
        }
    }
}
catch {
    Write-Error "Failed to install/update Chocolatey. Error: $_"
}

# Terminal Icons Install
$terminalIconsSuccess = $false
try {
    Write-Host "Checking for Terminal-Icons module..."
    # Check if Terminal-Icons is already installed
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Write-Host "Terminal-Icons module is already installed."
        $terminalIconsSuccess = $true
        $successCount++
    }
    else {
        Write-Host "Installing Terminal-Icons module..."
        # Configure TLS 1.2 for PowerShell Gallery
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Make sure PSGallery is trusted
        if ((Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue).InstallationPolicy -ne "Trusted") {
            Write-Host "Setting PSGallery as a trusted repository..."
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        }
        
        # Register default repository if needed
        if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
            Write-Host "Registering PSGallery repository..."
            Register-PSRepository -Default -Verbose
        }
        
        # Install the module
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser
        
        # Verify installation
        if (Get-Module -ListAvailable -Name Terminal-Icons) {
            Write-Host "Terminal-Icons module installed successfully."
            $terminalIconsSuccess = $true
            $successCount++
        }
        else {
            throw "Terminal-Icons module installation verification failed."
        }
    }
}
catch {
    Write-Error "Failed to install Terminal-Icons module. Error: $_"
    Write-Host "Attempting alternative installation method..."
    
    try {
        # Alternative installation method using direct download
        $moduleDir = "$HOME\Documents\PowerShell\Modules\Terminal-Icons"
        if (-not (Test-Path $moduleDir)) {
            New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
        }
        
        # Download from GitHub
        $zipUrl = "https://github.com/devblackops/Terminal-Icons/archive/refs/heads/main.zip"
        $zipPath = "$env:TEMP\Terminal-Icons.zip"
        $extractPath = "$env:TEMP\Terminal-Icons"
        
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Copy files to module directory
        Copy-Item -Path "$extractPath\Terminal-Icons-main\*" -Destination $moduleDir -Recurse -Force
        
        # Clean up
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        # Verify installation
        if (Get-Module -ListAvailable -Name Terminal-Icons) {
            Write-Host "Terminal-Icons module installed successfully via alternative method."
            $terminalIconsSuccess = $true
            $successCount++
        }
    }
    catch {
        Write-Error "Alternative installation method for Terminal-Icons failed. Error: $_"
    }
}

# zoxide Install
$zoxideSuccess = $false
try {
    Write-Host "Checking for zoxide installation..."
    # Check if zoxide is already installed
    $zoxideInstalled = $null
    try {
        $zoxideInstalled = winget list --id ajeetdsouza.zoxide
    }
    catch {
        # Ignore errors from winget list
    }

    if ($zoxideInstalled -and $zoxideInstalled -match "zoxide") {
        Write-Host "zoxide is already installed. Checking for updates..."
        winget upgrade -e --id ajeetdsouza.zoxide
    }
    else {
        Write-Host "Installing zoxide..."
        winget install -e --id ajeetdsouza.zoxide
    }
    
    # Verify installation
    $zoxideVerify = winget list --id ajeetdsouza.zoxide
    if ($zoxideVerify -match "zoxide") {
        Write-Host "zoxide installed/updated successfully."
        $zoxideSuccess = $true
        $successCount++
    }
}
catch {
    Write-Error "Failed to install zoxide. Error: $_"
}

# Final check and message to the user
Write-Host "`n===== Installation Summary ====="
Write-Host "PowerShell Profile: $($profileSuccess ? "✅ Success" : "❌ Failed")"
Write-Host "Oh My Posh: $($ompSuccess ? "✅ Success" : "❌ Failed")"
Write-Host "Nerd Font: $($fontSuccess ? "✅ Success" : "❌ Failed")"
Write-Host "Chocolatey: $($chocoSuccess ? "✅ Success" : "❌ Failed")"
Write-Host "Terminal-Icons: $($terminalIconsSuccess ? "✅ Success" : "❌ Failed")"
Write-Host "zoxide: $($zoxideSuccess ? "✅ Success" : "❌ Failed")"
Write-Host "============================="

if ($successCount -eq $totalSteps) {
    Write-Host "`n✅ Setup completed successfully! Please restart your PowerShell session to apply changes." -ForegroundColor Green
}
else {
    Write-Host "`n⚠️ Setup completed with some components failing. Please check the error messages above." -ForegroundColor Yellow
    Write-Host "Successfully installed $successCount out of $totalSteps components."
}

# Add instructions for manual verification
Write-Host "`n===== Next Steps ====="
Write-Host "1. Restart your PowerShell session"
Write-Host "2. Verify your profile is working by checking for the Oh My Posh prompt"
Write-Host "3. Make sure your terminal is using the CaskaydiaCove NF font"
Write-Host "4. Test Terminal-Icons by running: Get-ChildItem | Format-Table -View childrenWithIcon"
Write-Host "5. Test zoxide by running: z --help"
Write-Host "============================="

# If running from a cloned repo, configure symlink-based profile setup.
$setProfileScript = Join-Path -Path $PSScriptRoot -ChildPath "setprofile.ps1"
if (Test-Path -Path $setProfileScript -PathType Leaf) {
    try {
        Write-Host "`nConfiguring symlink-based profile setup..." -ForegroundColor Cyan
        & $setProfileScript
        Write-Host "Optional: run .\setprofile-repo-assets.ps1 to link repo Modules/CustomThemes." -ForegroundColor DarkGray
    }
    catch {
        Write-Warning "Failed to run setprofile.ps1 automatically: $($_.Exception.Message)"
        Write-Host "You can run it manually from repo root: .\setprofile.ps1" -ForegroundColor Yellow
    }
}
