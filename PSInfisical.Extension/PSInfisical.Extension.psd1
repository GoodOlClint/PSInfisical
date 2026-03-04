@{

    # Script module file associated with this manifest
    RootModule        = 'PSInfisical.Extension.psm1'

    # Version number — kept in sync with parent module
    ModuleVersion     = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID              = '7ccd313a-09d6-41f3-8731-bd0939ee01ca'

    # Author of this module
    Author            = 'PSInfisical Contributors'

    # Description of the functionality provided by this module
    Description       = 'SecretManagement vault extension for PSInfisical. Provides Infisical secrets access through the standard Get-Secret / Set-Secret interface.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export — exactly the 5 required by SecretManagement
    FunctionsToExport = @(
        'Get-Secret'
        'Set-Secret'
        'Remove-Secret'
        'Get-SecretInfo'
        'Test-SecretVault'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    AliasesToExport    = @()

    # Required modules — SecretManagement is always the caller that loads this
    # extension, so it must NOT be declared here (doing so causes a circular
    # dependency during Register-SecretVault's internal module loading).
    RequiredModules    = @()

}

