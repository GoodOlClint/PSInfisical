# Get-InfisicalProjectRole.ps1
# Retrieves roles from an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalProjectRole {
    <#
    .SYNOPSIS
        Retrieves roles from an Infisical project.

    .DESCRIPTION
        Lists all roles configured in the specified project, including built-in
        roles (admin, member, viewer) and custom roles.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Get-InfisicalProjectRole

        Returns all roles in the current project.

    .EXAMPLE
        Get-InfisicalProjectRole -ProjectId 'proj-456'

        Returns roles for a specific project.

    .OUTPUTS
        PSCustomObject with Id, Name, Slug, Description, and ProjectId properties.

    .LINK
        New-InfisicalProjectRole
    .LINK
        Remove-InfisicalProjectRole
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/projects/$resolvedProjectId/roles" -Session $session

    if ($null -eq $response -or $null -eq $response.roles) {
        return
    }

    foreach ($role in $response.roles) {
        $id = if ($role -is [hashtable]) { $role['id'] } else { $role.id }
        $name = if ($role -is [hashtable]) { $role['name'] } else { $role.name }
        $slug = if ($role -is [hashtable]) { $role['slug'] } else { $role.slug }
        $desc = if ($role -is [hashtable] -and $role.ContainsKey('description')) { $role['description'] } elseif ($role -isnot [hashtable] -and $role.description) { $role.description } else { '' }

        [PSCustomObject]@{
            PSTypeName  = 'InfisicalProjectRole'
            Id          = $id
            Name        = $name
            Slug        = $slug
            Description = $desc
            ProjectId   = $resolvedProjectId
        }
    }
}
