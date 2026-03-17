# Get-InfisicalSecrets.ps1
# Retrieves all secrets in a given path from the Infisical API.
# Called by: User directly. Supports pipeline output.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalSecrets {
    <#
    .SYNOPSIS
        Retrieves all secrets from an Infisical path.

    .DESCRIPTION
        Fetches all secrets from the specified Infisical environment and path.
        Returns InfisicalSecret objects that are pipeline-friendly, emitting each
        secret individually. Use -AsHashtable for direct variable injection.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Recursive
        Include secrets from sub-paths.

    .PARAMETER ExpandSecretReferences
        Expand secret reference expressions (e.g., ${SECRET_NAME}) in values.

    .PARAMETER IncludeImports
        Include secrets imported from other environments/paths.

    .PARAMETER IncludePersonalOverrides
        Include personal secret overrides in addition to shared secrets.

    .PARAMETER TagSlugs
        Filter secrets server-side by tag slugs. Only secrets with matching tags are returned.

    .PARAMETER MetadataFilter
        Filter secrets server-side by metadata key-value pairs.

    .PARAMETER Filter
        A scriptblock for client-side filtering, e.g. { $_.Name -like "DB_*" }.

    .PARAMETER AsHashtable
        Return a hashtable of Name=Value (plaintext strings) instead of objects.

    .EXAMPLE
        Get-InfisicalSecrets

        Returns all secrets in the default environment and root path.

    .EXAMPLE
        Get-InfisicalSecrets -Environment 'staging' -SecretPath '/database'

        Returns all secrets in the staging environment under the /database path.

    .EXAMPLE
        Get-InfisicalSecrets -Filter { $_.Name -like 'DB_*' } -AsHashtable

        Returns a hashtable of secrets whose names start with "DB_".

    .OUTPUTS
        [InfisicalSecret[]] by default, or [hashtable] when -AsHashtable is specified.

    .NOTES
        Each secret is emitted individually to the pipeline for streaming processing.
        The -Filter parameter runs client-side after all secrets are retrieved.

    .LINK
        Get-InfisicalSecret
    .LINK
        Remove-InfisicalSecret
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns a collection of secrets; plural is intentional')]
    [CmdletBinding()]
    [OutputType([InfisicalSecret[]], [hashtable])]
    param(
        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $Recursive,

        [Parameter()]
        [switch] $ExpandSecretReferences,

        [Parameter()]
        [switch] $IncludeImports,

        [Parameter()]
        [switch] $IncludePersonalOverrides,

        [Parameter()]
        [string[]] $TagSlugs,

        [Parameter()]
        [hashtable] $MetadataFilter,

        [Parameter()]
        [scriptblock] $Filter,

        [Parameter()]
        [switch] $AsHashtable
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    $queryParams = @{
        projectId = $resolvedProjectId
        environment = $resolvedEnvironment
        secretPath  = $SecretPath
    }

    if ($Recursive.IsPresent) {
        $queryParams['recursive'] = 'true'
    }

    if ($ExpandSecretReferences.IsPresent) {
        $queryParams['expandSecretReferences'] = 'true'
    }

    if ($IncludeImports.IsPresent) {
        $queryParams['includeImports'] = 'true'
    }

    if ($IncludePersonalOverrides.IsPresent) {
        $queryParams['includePersonalOverrides'] = 'true'
    }

    if ($null -ne $TagSlugs -and $TagSlugs.Count -gt 0) {
        $queryParams['tagSlugs'] = $TagSlugs -join ','
    }

    if ($null -ne $MetadataFilter -and $MetadataFilter.Count -gt 0) {
        # metadataFilter uses key=value comma-separated format
        $filterParts = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $MetadataFilter.Keys) {
            $filterParts.Add("$key=$($MetadataFilter[$key])")
        }
        $queryParams['metadataFilter'] = $filterParts -join ','
    }

    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v4/secrets' -QueryParameters $queryParams -Session $session

    if ($null -eq $response -or $null -eq $response.secrets) {
        if ($AsHashtable.IsPresent) {
            return @{}
        }
        return
    }

    $secrets = [System.Collections.Generic.List[InfisicalSecret]]::new()

    foreach ($secretData in $response.secrets) {
        $secret = ConvertTo-InfisicalSecret -SecretData $secretData -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
        $secrets.Add($secret)
    }

    # Apply client-side filter if specified
    if ($null -ne $Filter) {
        $secrets = [System.Collections.Generic.List[InfisicalSecret]]($secrets | Where-Object -FilterScript $Filter)
    }

    if ($AsHashtable.IsPresent) {
        $result = @{}
        foreach ($s in $secrets) {
            $result[$s.Name] = $s.GetValue()
        }
        return $result
    }

    # Emit objects individually for pipeline support
    foreach ($s in $secrets) {
        $s
    }
}
