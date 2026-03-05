# NetworkTools.psm1
# Network-related functions and utilities

# Define any module-level variables here
$script:moduleRoot = $PSScriptRoot

#region Public Functions

function Get-PublicIPAddress {
    <#
    .SYNOPSIS
        Retrieves the public IP address of the machine
    .DESCRIPTION
        Gets the public IP address by querying an external service
    .EXAMPLE
        Get-PublicIPAddress
    #>
    [CmdletBinding()]
    param()
    
    try {
        $response = Invoke-WebRequest -Uri "http://ifconfig.me/ip" -UseBasicParsing -TimeoutSec 5
        return $response.Content
    }
    catch {
        Write-Error "Failed to retrieve public IP address: $_"
        return $null
    }
}

function Test-InternetConnection {
    <#
    .SYNOPSIS
        Tests internet connectivity
    .DESCRIPTION
        Checks if the machine can connect to the internet
    .PARAMETER Target
        The target host to ping (default: 8.8.8.8)
    .PARAMETER Count
        Number of pings to send (default: 2)
    .EXAMPLE
        Test-InternetConnection
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Target = "8.8.8.8",
        
        [Parameter()]
        [int]$Count = 2
    )
    
    $result = Test-Connection -ComputerName $Target -Count $Count -Quiet
    if ($result) {
        Write-Host "Internet connection is available" -ForegroundColor Green
    }
    else {
        Write-Host "Internet connection is not available" -ForegroundColor Red
    }
    return $result
}

function Get-NetworkStatistics {
    <#
    .SYNOPSIS
        Shows network statistics
    .DESCRIPTION
        Displays various network statistics including connections
    .EXAMPLE
        Get-NetworkStatistics
    #>
    [CmdletBinding()]
    param()
    
    $netstat = & "$env:SystemRoot\System32\netstat.exe" -ano
    return $netstat
}

function Start-WinUtil {
    <#
    .SYNOPSIS
        Launches the WinUtil tool
    .DESCRIPTION
        Runs the Chris Titus Tech Windows utility
    .EXAMPLE
        Start-WinUtil
    #>
    [CmdletBinding()]
    param()
    
    Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

function Start-WinUtilDev {
    <#
    .SYNOPSIS
        Launches the WinUtil development version
    .DESCRIPTION
        Runs the Chris Titus Tech Windows utility pre-release version
    .EXAMPLE
        Start-WinUtilDev
    #>
    [CmdletBinding()]
    param()
    
    Invoke-RestMethod https://christitus.com/windev | Invoke-Expression
}

#endregion

# Aliases
New-Alias -Name Get-PubIP -Value Get-PublicIPAddress -Force -Scope Global
New-Alias -Name flushdns -Value Clear-DnsClientCache -Force -Scope Global
New-Alias -Name pingtest -Value Test-InternetConnection -Force -Scope Global
New-Alias -Name nstat -Value Get-NetworkStatistics -Force -Scope Global
New-Alias -Name winutil -Value Start-WinUtil -Force -Scope Global
New-Alias -Name winutildev -Value Start-WinUtilDev -Force -Scope Global

# Export functions and aliases
Export-ModuleMember -Function Get-PublicIPAddress, Clear-DnsClientCache, Test-InternetConnection, 
Get-NetworkStatistics, Start-WinUtil, Start-WinUtilDev
Export-ModuleMember -Alias Get-PubIP, flushdns, pingtest, nstat, winutil, winutildev 
