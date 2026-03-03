@{

    # Script module file associated with this manifest
    RootModule        = 'PSInfisical.psm1'

    # Version number of this module
    ModuleVersion     = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID              = '5f2b4b93-c874-454e-9bd3-928f093167d6'

    # Author of this module
    Author            = 'PSInfisical Contributors'

    # Company or vendor of this module
    CompanyName       = ''

    # Copyright statement for this module
    Copyright         = '(c) PSInfisical Contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'A PowerShell module providing an idiomatic interface to the Infisical secrets management API. Supports universal auth, token-based auth, and CRUD operations on secrets with SecureString handling.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module — explicit list of public functions only
    FunctionsToExport = @(
        'Connect-Infisical'
        'Disconnect-Infisical'
        'Get-InfisicalSecret'
        'Get-InfisicalSecrets'
        'New-InfisicalSecret'
        'Set-InfisicalSecret'
        'Remove-InfisicalSecret'
        'Get-InfisicalSecretVersion'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    AliasesToExport    = @()

    # Scripts to run before importing the module — exposes class types globally
    ScriptsToProcess  = @(
        'Classes/InfisicalSession.ps1'
        'Classes/InfisicalSecret.ps1'
    )

    # Required modules
    RequiredModules    = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            Tags         = @('Infisical', 'Secrets', 'SecretManagement', 'API', 'DevOps', 'Security')
            LicenseUri   = 'https://github.com/PLACEHOLDER/PSInfisical/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/PLACEHOLDER/PSInfisical'
            ReleaseNotes = 'Initial release — secrets CRUD, universal auth, token auth, SecureString handling.'
        }
    }

}
