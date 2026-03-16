# New-InfisicalFolder.ps1
# Creates a new folder in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalFolder class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalFolder {
    <#
    .SYNOPSIS
        Creates a new folder in Infisical.

    .DESCRIPTION
        Creates a folder at the specified path in the Infisical secrets manager.
        Folders organize secrets into hierarchical paths.

    .PARAMETER Name
        The name of the folder to create.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The parent path where the folder will be created. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Description
        An optional description for the folder.

    .PARAMETER PassThru
        Return the created InfisicalFolder object.

    .EXAMPLE
        New-InfisicalFolder -Name 'database'

        Creates a folder named "database" at the root path.

    .EXAMPLE
        New-InfisicalFolder -Name 'credentials' -SecretPath '/database' -PassThru

        Creates a folder and returns the created object.

    .OUTPUTS
        [InfisicalFolder] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalFolder
    .LINK
        Set-InfisicalFolder
    .LINK
        Remove-InfisicalFolder
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalFolder])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [string] $Description,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Creating folder '$Name' at path '$SecretPath' (environment: $resolvedEnvironment)")) {
        $body = @{
            projectId   = $resolvedProjectId
            environment = $resolvedEnvironment
            name        = $Name
            path        = $SecretPath
        }

        if (-not [string]::IsNullOrEmpty($Description)) {
            $body['description'] = $Description
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint '/api/v2/folders' -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.folder) {
            return ConvertTo-InfisicalFolder -FolderData $response.folder -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
        }
    }
}
