# Remove-InfisicalEnvironment.ps1
# Deletes an environment from an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalEnvironment {
    <#
    .SYNOPSIS
        Removes an environment from an Infisical project.

    .DESCRIPTION
        Deletes the specified environment and all secrets stored in it. Confirms by default.

    .PARAMETER Id
        The ID of the environment to delete.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Remove-InfisicalEnvironment -Id 'env-abc-123' -Confirm:$false

        Deletes an environment without confirmation.

    .EXAMPLE
        Remove-InfisicalEnvironment -Id 'env-abc-123' -WhatIf

        Previews the deletion without actually removing the environment.

    .OUTPUTS
        None

    .NOTES
        This deletes ALL secrets in the environment. Use -WhatIf to preview.

    .LINK
        Get-InfisicalEnvironment
    .LINK
        New-InfisicalEnvironment
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Deleting environment '$Id' from project '$resolvedProjectId'")) {
        $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v1/projects/$resolvedProjectId/environments/$Id" -Session $session

        if ($null -eq $response) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Environment '$Id' not found in project '$resolvedProjectId'."),
                'InfisicalEnvironmentNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Id
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
}
