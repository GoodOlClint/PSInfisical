# Remove-InfisicalProjectMember.ps1
# Revokes a machine identity's access to an Infisical project.
# Called by: User directly. Supports pipeline input.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalProjectMember {
    <#
    .SYNOPSIS
        Revokes a machine identity's access to an Infisical project.

    .DESCRIPTION
        Removes a machine identity's membership from the specified project,
        revoking all project-level permissions. Confirms by default.

    .PARAMETER IdentityId
        The ID of the machine identity to remove. Accepts pipeline input by property name.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Remove-InfisicalProjectMember -IdentityId 'identity-123' -Confirm:$false

        Revokes project access without confirmation.

    .EXAMPLE
        Get-InfisicalProjectMember | Where-Object Role -eq 'viewer' | Remove-InfisicalProjectMember

        Removes all viewer members via pipeline.

    .OUTPUTS
        None

    .NOTES
        This only removes project access. The identity itself is not deleted.

    .LINK
        Get-InfisicalProjectMember
    .LINK
        Add-InfisicalProjectMember
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId
    )

    process {
        $session = Get-InfisicalSession

        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Revoking identity '$IdentityId' from project '$resolvedProjectId'")) {
            $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v2/workspace/$resolvedProjectId/identity-memberships/$IdentityId" -Session $session

            if ($null -eq $response) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new("Identity '$IdentityId' is not a member of project '$resolvedProjectId'."),
                    'InfisicalProjectMemberNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $IdentityId
                )
                $PSCmdlet.WriteError($errorRecord)
            }
        }
    }
}
