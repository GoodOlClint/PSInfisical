# Get-InfisicalSecretImport.ps1
# Retrieves secret imports from an Infisical path.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecretImport class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalSecretImport {
    <#
    .SYNOPSIS
        Retrieves secret imports from an Infisical path.

    .DESCRIPTION
        Fetches secret imports configured at the specified environment and path.
        Secret imports allow one path to inherit secrets from another environment or path.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path to list imports for. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Get-InfisicalSecretImport

        Returns all secret imports at the default path and environment.

    .EXAMPLE
        Get-InfisicalSecretImport -Environment 'prod' -SecretPath '/app'

        Returns secret imports for the /app path in production.

    .OUTPUTS
        [InfisicalSecretImport[]]

    .LINK
        New-InfisicalSecretImport
    .LINK
        Remove-InfisicalSecretImport
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns a collection; plural matches resource name')]
    [CmdletBinding()]
    [OutputType([InfisicalSecretImport[]])]
    param(
        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    $queryParams = @{
        projectId   = $resolvedProjectId
        environment = $resolvedEnvironment
        path        = $SecretPath
    }

    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v2/secret-imports' -QueryParameters $queryParams -Session $session

    if ($null -eq $response -or $null -eq $response.secretImports) {
        return
    }

    foreach ($importData in $response.secretImports) {
        ConvertTo-InfisicalSecretImport -ImportData $importData -ProjectId $resolvedProjectId -Environment $resolvedEnvironment -Path $SecretPath
    }
}
