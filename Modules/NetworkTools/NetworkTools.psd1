# Module manifest for module 'NetworkTools'
@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'NetworkTools.psm1'

    # Version number of this module
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = '2339f560-9aa0-4253-ae81-f600e1d95c83'

    # Author of this module
    Author            = 'Armin Zou'

    # Description of the functionality provided by this module
    Description       = 'Network-related functions and utilities'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @('DnsClient')
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'Get-PublicIPAddress',
        'Clear-DnsClientCache',
        'Test-InternetConnection',
        'Get-NetworkStatistics',
        'Start-WinUtil',
        'Start-WinUtilDev'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport   = @(
        'Get-PubIP',
        'flushdns',
        'pingtest',
        'nstat',
        'winutil',
        'winutildev'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module
            Tags       = @('Network', 'Internet', 'DNS', 'Utilities')

            # A URL to the license for this module
            LicenseUri = ''

            # A URL to the main website for this project
            ProjectUri = ''
        }
    }
} 
