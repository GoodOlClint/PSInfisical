# Get-InfisicalIdentityMembership.ps1
# Lists which projects a machine identity belongs to.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalIdentityMembership {
    <#
    .SYNOPSIS
        Lists which projects a machine identity belongs to.

    .DESCRIPTION
        Retrieves all project memberships for the specified identity. Useful for
        auditing which projects an identity has access to.

    .PARAMETER IdentityId
        The ID of the machine identity.

    .EXAMPLE
        Get-InfisicalIdentityMembership -IdentityId 'identity-123'

        Returns all project memberships for the identity.

    .EXAMPLE
        Get-InfisicalIdentityMembership -IdentityId 'identity-123' | Where-Object Role -eq 'admin'

        Returns only projects where the identity has the admin role.

    .OUTPUTS
        PSCustomObject[] with ProjectId, ProjectName, Role, and CreatedAt properties.

    .LINK
        Get-InfisicalIdentity
    .LINK
        Add-InfisicalProjectMember
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId
    )

    $session = Get-InfisicalSession

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/identities/$IdentityId/identity-memberships" -Session $session

    if ($null -eq $response -or $null -eq $response.identityMemberships) {
        return
    }

    foreach ($membership in $response.identityMemberships) {
        $projectId = ''
        $projectName = ''
        $role = ''

        if ($membership -is [hashtable]) {
            if ($membership.ContainsKey('project') -and $membership['project']) {
                $projectId = $membership['project']['id']
                $projectName = $membership['project']['name']
            }
            if ($membership.ContainsKey('role')) { $role = $membership['role'] }
        } else {
            if ($membership.project) {
                $projectId = $membership.project.id
                $projectName = $membership.project.name
            }
            if ($membership.role) { $role = $membership.role }
        }

        $createdAt = [datetime]::MinValue
        if ($membership.createdAt) { [void][datetime]::TryParse($membership.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }

        [PSCustomObject]@{
            PSTypeName   = 'InfisicalIdentityMembership'
            IdentityId   = $IdentityId
            ProjectId    = $projectId
            ProjectName  = $projectName
            Role         = $role
            CreatedAt    = $createdAt
        }
    }
}
