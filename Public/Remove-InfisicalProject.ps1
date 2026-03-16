# Remove-InfisicalProject.ps1
# Deletes a project/workspace from Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalProject {
    <#
    .SYNOPSIS
        Removes a project from Infisical.

    .DESCRIPTION
        Deletes the specified project and all its secrets, folders, environments,
        and memberships. This is an extremely destructive operation. Confirms by default.

    .PARAMETER Id
        The ID of the project to delete.

    .EXAMPLE
        Remove-InfisicalProject -Id 'proj-abc-123' -Confirm:$false

        Deletes a project without confirmation.

    .OUTPUTS
        None

    .NOTES
        This permanently deletes ALL secrets, folders, and configurations in the project.

    .LINK
        Get-InfisicalProject
    .LINK
        New-InfisicalProject
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Deleting project '$Id' and ALL its contents")) {
        $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v2/workspace/$Id" -Session $session

        if ($null -eq $response) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Project '$Id' not found."),
                'InfisicalProjectNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Id
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
}
