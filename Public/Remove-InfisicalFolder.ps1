# Remove-InfisicalFolder.ps1
# Deletes a folder from Infisical.
# Called by: User directly. Supports pipeline input from Get-InfisicalFolder.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalFolder {
    <#
    .SYNOPSIS
        Removes a folder from Infisical.

    .DESCRIPTION
        Deletes the specified folder from the Infisical secrets manager. Use -ForceDelete
        to remove folders that contain secrets or sub-folders. Confirms by default.

    .PARAMETER Id
        The ID of the folder to remove. Accepts pipeline input by property name.

    .PARAMETER Name
        The name of the folder to remove (alternative to -Id).

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The path of the folder. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER ForceDelete
        Delete the folder even if it contains secrets or sub-folders.

    .EXAMPLE
        Remove-InfisicalFolder -Id 'folder-abc-123' -Confirm:$false

        Removes a folder by ID without confirmation.

    .EXAMPLE
        Remove-InfisicalFolder -Name 'old-folder' -ForceDelete

        Removes a folder by name, including all contents.

    .EXAMPLE
        Get-InfisicalFolder | Where-Object Name -like 'temp-*' | Remove-InfisicalFolder

        Removes folders matching a pattern via pipeline.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. Use -WhatIf to preview.

    .LINK
        Get-InfisicalFolder
    .LINK
        New-InfisicalFolder
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId,

        [Parameter()]
        [switch] $ForceDelete
    )

    process {
        $session = Get-InfisicalSession

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        $folderIdentifier = if ($PSCmdlet.ParameterSetName -eq 'ById') { $Id } else { $Name }
        $identifierLabel = if ($PSCmdlet.ParameterSetName -eq 'ById') { "ID '$Id'" } else { "name '$Name'" }

        if ($PSCmdlet.ShouldProcess("Removing folder $identifierLabel from path '$SecretPath' (environment: $resolvedEnvironment)")) {
            $body = @{
                projectId   = $resolvedProjectId
                environment = $resolvedEnvironment
                path        = $SecretPath
            }

            if ($ForceDelete.IsPresent) {
                $body['forceDelete'] = $true
            }

            $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v2/folders/$folderIdentifier" -Body $body -Session $session

            if ($null -eq $response) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new(
                        "Folder $identifierLabel not found in environment '$resolvedEnvironment' at path '$SecretPath'."
                    ),
                    'InfisicalFolderNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $folderIdentifier
                )
                $PSCmdlet.WriteError($errorRecord)
            }
        }
    }
}
