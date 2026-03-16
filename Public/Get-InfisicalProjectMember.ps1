# Get-InfisicalProjectMember.ps1
# Retrieves identity memberships from an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalProjectMember {
    <#
    .SYNOPSIS
        Retrieves identity memberships from an Infisical project.

    .DESCRIPTION
        Lists all machine identities that have been granted access to the specified
        project, along with their roles.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Get-InfisicalProjectMember

        Returns all identity memberships in the current project.

    .EXAMPLE
        Get-InfisicalProjectMember -ProjectId 'proj-456'

        Returns memberships for a specific project.

    .OUTPUTS
        PSCustomObject with IdentityId, IdentityName, Role, RoleId, CreatedAt, and UpdatedAt properties.

    .LINK
        Add-InfisicalProjectMember
    .LINK
        Remove-InfisicalProjectMember
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v2/workspace/$resolvedProjectId/identity-memberships" -Session $session

    if ($null -eq $response -or $null -eq $response.identityMemberships) {
        return
    }

    foreach ($membership in $response.identityMemberships) {
        $identityId = if ($membership -is [hashtable]) {
            if ($membership.ContainsKey('identityId')) { $membership['identityId'] }
            elseif ($membership.ContainsKey('identity') -and $membership['identity']) { $membership['identity']['id'] }
            else { '' }
        } else {
            if ($membership.identityId) { $membership.identityId }
            elseif ($membership.identity) { $membership.identity.id }
            else { '' }
        }

        $identityName = if ($membership -is [hashtable] -and $membership.ContainsKey('identity') -and $membership['identity']) {
            $membership['identity']['name']
        } elseif ($membership -isnot [hashtable] -and $membership.identity) {
            $membership.identity.name
        } else { '' }

        $role = if ($membership -is [hashtable] -and $membership.ContainsKey('role')) { $membership['role'] } elseif ($membership -isnot [hashtable] -and $membership.role) { $membership.role } else { '' }
        $roleId = if ($membership -is [hashtable] -and $membership.ContainsKey('roleId')) { $membership['roleId'] } elseif ($membership -isnot [hashtable] -and $membership.roleId) { $membership.roleId } else { '' }

        $createdAt = [datetime]::MinValue
        $updatedAt = [datetime]::MinValue
        if ($membership.createdAt) { [void][datetime]::TryParse($membership.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }
        if ($membership.updatedAt) { [void][datetime]::TryParse($membership.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$updatedAt) }

        [PSCustomObject]@{
            PSTypeName   = 'InfisicalProjectMember'
            IdentityId   = $identityId
            IdentityName = $identityName
            Role         = $role
            RoleId       = $roleId
            ProjectId    = $resolvedProjectId
            CreatedAt    = $createdAt
            UpdatedAt    = $updatedAt
        }
    }
}
