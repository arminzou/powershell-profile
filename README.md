# 🚀 PowerShell Profile

Transform your PowerShell experience with a stylish, feature-rich terminal environment that rivals Linux terminals in both aesthetics and functionality.


## ✨ Features

- 🎨 Beautiful prompt with Git integration
- 🔍 Syntax highlighting
- 📁 File icons with Terminal-Icons
- 📊 Intelligent command history with PSReadLine
- 🧠 Smart directory navigation with zoxide
- 🛠️ Chocolatey package manager integration

## 💻 Quick Installation

Run this command in an **elevated PowerShell** window:

```powershell
irm "https://github.com/arminzou/PowerShell-Profile/raw/master/setup.ps1" | iex
```

The setup script automatically installs:
- Oh My Posh
- Nerd Fonts (CaskaydiaCove NF)
- Terminal-Icons
- Chocolatey
- zoxide

## 🔤 Font Installation

For the best experience, you need a Nerd Font. Choose one of these methods:

### Option 1: Using Oh My Posh (Recommended)

```powershell
oh-my-posh font install
```
1. Run the command `oh-my-posh font install`
2. Select your preferred font from the list using arrow keys and press Enter.

### Option 2: Manual Installation

The setup script attempts to install CaskaydiaCove NF automatically by default. If that fails:

1. Download [CaskaydiaCove NF](https://www.nerdfonts.com/font-downloads)
2. Extract and install the font files
3. Configure your terminal to use the installed font


## ⚙️ Customizing Your Profile

**Important:** keep `Microsoft.PowerShell_profile.ps1` in this repo as your shared base profile.

Use layered customization:

1. Clone this repo anywhere.
2. Run `.\setup.ps1` (recommended) from the repo root.
3. Edit your local override file at `$HOME\Documents\PowerShell\profile.local.ps1`.

When run from a clone, `setup.ps1` calls `setprofile.ps1` to create a symlink for:
- your profile file

Repo `Modules` and `CustomThemes` are now optional. If you want those linked from the repo, run:

```powershell
.\setprofile-repo-assets.ps1
```

`setprofile.ps1` is kept as a fast re-link utility (for example, after moving the repo path).
The repo profile loads `profile.local.ps1` (your machine/user-specific overrides) at the end.

This lets you sync the repo across machines while keeping personal changes local.

## 🔧 Troubleshooting

If you encounter any issues:

1. Make sure you're running PowerShell as Administrator
2. Check that your terminal is using the installed Nerd Font
3. Restart your PowerShell session after installation
4. Run `Test-ProfileSetup` to diagnose common issues

## 📚 Useful Commands

```powershell
# Smart directory navigation
z [folder name]

# Edit your custom profile
Edit-Profile

# Update your PowerShell profile
Update-Profile

# Display all useful commands
Show-Help 
```
