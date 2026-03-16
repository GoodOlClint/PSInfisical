# Remove-InfisicalTag.ps1
# Deletes a tag from an Infisical project.
# Called by: User directly. Supports pipeline input from Get-InfisicalTag.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalTag {
    <#
    .SYNOPSIS
        Removes a tag from an Infisical project.

    .DESCRIPTION
        Deletes the specified tag from the project. Confirms by default.

    .PARAMETER Id
        The ID of the tag to remove. Accepts pipeline input by property name.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Remove-InfisicalTag -Id 'tag-abc-123' -Confirm:$false

        Removes a tag without confirmation.

    .EXAMPLE
        Get-InfisicalTag | Where-Object Slug -like 'temp-*' | Remove-InfisicalTag

        Removes tags matching a pattern via pipeline.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. Use -WhatIf to preview.

    .LINK
        Get-InfisicalTag
    .LINK
        New-InfisicalTag
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId
    )

    process {
        $session = Get-InfisicalSession

        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Removing tag '$Id' from project '$resolvedProjectId'")) {
            $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v1/projects/$resolvedProjectId/tags/$Id" -Session $session

            if ($null -eq $response) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new("Tag '$Id' not found in project '$resolvedProjectId'."),
                    'InfisicalTagNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Id
                )
                $PSCmdlet.WriteError($errorRecord)
            }
        }
    }
}
