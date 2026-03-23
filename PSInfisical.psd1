@{

    # Script module file associated with this manifest
    RootModule        = 'PSInfisical.psm1'

    # Version number of this module
    ModuleVersion     = '0.4.1'

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
    Description       = 'A PowerShell module providing an idiomatic interface to the Infisical secrets management API. Supports universal auth, token-based auth, CRUD operations on secrets with SecureString handling, and Microsoft.PowerShell.SecretManagement vault extension.'

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
        'Get-InfisicalFolder'
        'New-InfisicalFolder'
        'Set-InfisicalFolder'
        'Remove-InfisicalFolder'
        'Get-InfisicalTag'
        'New-InfisicalTag'
        'Set-InfisicalTag'
        'Remove-InfisicalTag'
        'Get-InfisicalSecretImport'
        'New-InfisicalSecretImport'
        'Set-InfisicalSecretImport'
        'Remove-InfisicalSecretImport'
        'New-InfisicalSecretBulk'
        'Set-InfisicalSecretBulk'
        'Remove-InfisicalSecretBulk'
        'Get-InfisicalEnvironment'
        'Get-InfisicalProject'
        'Get-InfisicalIdentity'
        'New-InfisicalIdentity'
        'Set-InfisicalIdentity'
        'Remove-InfisicalIdentity'
        'Add-InfisicalIdentityAuth'
        'Get-InfisicalIdentityAuth'
        'Remove-InfisicalIdentityAuth'
        'New-InfisicalClientSecret'
        'Get-InfisicalProjectMember'
        'Add-InfisicalProjectMember'
        'Remove-InfisicalProjectMember'
        'Get-InfisicalProjectRole'
        'New-InfisicalProjectRole'
        'Remove-InfisicalProjectRole'
        'Set-InfisicalProjectMember'
        'Get-InfisicalClientSecret'
        'Remove-InfisicalClientSecret'
        'Get-InfisicalIdentityMembership'
        'New-InfisicalProject'
        'Remove-InfisicalProject'
        'New-InfisicalEnvironment'
        'Set-InfisicalEnvironment'
        'Remove-InfisicalEnvironment'
        'Set-InfisicalSession'
        'Set-InfisicalProject'
        'Get-InfisicalOrganization'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    AliasesToExport    = @()

    # Class types (InfisicalSession, InfisicalSecret) are dot-sourced inside
    # the RootModule (PSInfisical.psm1). Use 'using module PSInfisical' in
    # scripts that need direct access to these types.
    # NOTE: ScriptsToProcess is intentionally empty — listing class files
    # here breaks SecretManagement's internal module loading in Register-SecretVault.
    ScriptsToProcess  = @()

    # SecretManagement vault extension — required by Register-SecretVault.
    # The extension's psm1 guards against circular import by checking
    # if PSInfisical is already loaded before importing the parent module.
    NestedModules     = @('.\PSInfisical.Extension')

    # Required modules
    RequiredModules    = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            Tags         = @('PSInfisical', 'Infisical', 'Secrets', 'SecretManagement', 'API', 'DevOps', 'Security')
            LicenseUri   = 'https://github.com/GoodOlClint/PSInfisical/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/GoodOlClint/PSInfisical'
            ReleaseNotes = @'
## 0.4.1
- Metadata-only release to fix PSGallery tag indexing (redirect to 0.2.0 and tag search broken).

## 0.4.0
### Added
- Email/password login: Connect-Infisical -Email -Password
- Set-InfisicalSession: update OrganizationId, ProjectId, or Environment after connecting
- Set-InfisicalProject: rename projects, toggle auto-capitalization
- Get-InfisicalOrganization: list organizations accessible to current user/identity
- OrganizationId auto-resolved from JWT during connect
- Transparent v3 API fallback for older self-hosted Infisical instances
- Typed response objects: InfisicalIdentityAuth, InfisicalClientSecret, InfisicalProjectMembership
- -PassThru on Add-InfisicalIdentityAuth and Add-InfisicalProjectMember
- 464 unit tests and 32 integration tests
### Changed
- -ProjectId is now optional on Connect-Infisical
- -OrganizationId is now optional on New-InfisicalIdentity, Get-InfisicalIdentity, New-InfisicalProject
- New-InfisicalClientSecret always returns typed object
### Fixed
- Always send JSON body on POST/PATCH/DELETE
- Strict mode errors in ConvertTo-InfisicalIdentity
- Identity list response unwrapping
- Project response key handling (project vs workspace)
- Token expiry extracted from JWT exp claim for email/password auth
'@
        }
    }

}

