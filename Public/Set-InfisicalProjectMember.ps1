# Set-InfisicalProjectMember.ps1
# Updates a machine identity's role in an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalProjectMember {
    <#
    .SYNOPSIS
        Updates a machine identity's role in an Infisical project.

    .DESCRIPTION
        Changes the project-level role assigned to a machine identity without
        needing to remove and re-add the membership.

    .PARAMETER IdentityId
        The ID of the machine identity. Accepts pipeline input by property name.

    .PARAMETER Role
        The new project role slug to assign.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Set-InfisicalProjectMember -IdentityId 'identity-123' -Role 'admin'

        Promotes an identity to admin in the current project.

    .EXAMPLE
        Get-InfisicalProjectMember | Where-Object Role -eq 'member' |
            Set-InfisicalProjectMember -Role 'viewer'

        Demotes all members to viewer via pipeline.

    .OUTPUTS
        PSCustomObject with updated membership details.

    .LINK
        Get-InfisicalProjectMember
    .LINK
        Add-InfisicalProjectMember
    .LINK
        Remove-InfisicalProjectMember
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Role,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId
    )

    process {
        $session = Get-InfisicalSession

        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Updating identity '$IdentityId' to role '$Role' on project '$resolvedProjectId'")) {
            $body = @{
                role = $Role
            }

            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v2/workspace/$resolvedProjectId/identity-memberships/$IdentityId" -Body $body -Session $session

            return $response
        }
    }
}
