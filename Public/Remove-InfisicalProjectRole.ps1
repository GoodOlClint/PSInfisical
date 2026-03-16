# Remove-InfisicalProjectRole.ps1
# Deletes a custom role from an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalProjectRole {
    <#
    .SYNOPSIS
        Removes a custom role from an Infisical project.

    .DESCRIPTION
        Deletes the specified custom role. Built-in roles cannot be deleted.
        Confirms by default.

    .PARAMETER RoleId
        The ID of the role to remove.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Remove-InfisicalProjectRole -RoleId 'role-abc-123' -Confirm:$false

        Deletes a custom role without confirmation.

    .OUTPUTS
        None

    .NOTES
        Built-in roles (admin, member, viewer, no-access) cannot be deleted.

    .LINK
        Get-InfisicalProjectRole
    .LINK
        New-InfisicalProjectRole
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $RoleId,

        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Removing role '$RoleId' from project '$resolvedProjectId'")) {
        $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v1/projects/$resolvedProjectId/roles/$RoleId" -Session $session

        if ($null -eq $response) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Role '$RoleId' not found in project '$resolvedProjectId'."),
                'InfisicalProjectRoleNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $RoleId
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
}
