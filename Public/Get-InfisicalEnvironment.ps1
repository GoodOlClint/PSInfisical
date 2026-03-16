# Get-InfisicalEnvironment.ps1
# Retrieves environments from an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalEnvironment {
    <#
    .SYNOPSIS
        Retrieves environments from an Infisical project.

    .DESCRIPTION
        Lists all environments configured in the specified project. Useful for
        discovery and validation of environment slugs before running secret operations.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Get-InfisicalEnvironment

        Returns all environments in the current project.

    .EXAMPLE
        Get-InfisicalEnvironment -ProjectId 'proj-456'

        Returns environments for a specific project.

    .OUTPUTS
        PSCustomObject with Id, Name, Slug, and Position properties.

    .LINK
        Get-InfisicalProject
    .LINK
        Connect-Infisical
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/projects/$resolvedProjectId/environments" -Session $session

    if ($null -eq $response -or $null -eq $response.environments) {
        return
    }

    foreach ($env in $response.environments) {
        $id = if ($env -is [hashtable]) { $env['id'] } else { $env.id }
        $name = if ($env -is [hashtable]) { $env['name'] } else { $env.name }
        $slug = if ($env -is [hashtable]) { $env['slug'] } else { $env.slug }
        $position = if ($env -is [hashtable] -and $env.ContainsKey('position')) { [int]$env['position'] } elseif ($null -ne $env.position) { [int]$env.position } else { 0 }

        [PSCustomObject]@{
            PSTypeName = 'InfisicalEnvironment'
            Id         = $id
            Name       = $name
            Slug       = $slug
            Position   = $position
        }
    }
}
