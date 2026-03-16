# Add-InfisicalProjectMember.ps1
# Grants a machine identity access to an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Add-InfisicalProjectMember {
    <#
    .SYNOPSIS
        Grants a machine identity access to an Infisical project.

    .DESCRIPTION
        Adds a machine identity as a member of the specified project with the given role.
        The identity must already exist in the organization.

    .PARAMETER IdentityId
        The ID of the machine identity to add.

    .PARAMETER Role
        The project role slug to assign (e.g., 'admin', 'member', 'viewer', or a custom role slug).

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Add-InfisicalProjectMember -IdentityId 'identity-123' -Role 'member'

        Grants the identity member access to the current project.

    .EXAMPLE
        Add-InfisicalProjectMember -IdentityId 'identity-123' -Role 'viewer' -ProjectId 'proj-456'

        Grants viewer access to a specific project.

    .OUTPUTS
        PSCustomObject with membership details.

    .LINK
        Get-InfisicalProjectMember
    .LINK
        Remove-InfisicalProjectMember
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Role,

        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Granting identity '$IdentityId' role '$Role' on project '$resolvedProjectId'")) {
        $body = @{
            role = $Role
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v2/workspace/$resolvedProjectId/identity-memberships/$IdentityId" -Body $body -Session $session

        return $response
    }
}
