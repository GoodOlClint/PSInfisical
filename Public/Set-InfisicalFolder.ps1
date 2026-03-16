# Set-InfisicalFolder.ps1
# Updates an existing folder in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalFolder class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalFolder {
    <#
    .SYNOPSIS
        Updates an existing folder in Infisical.

    .DESCRIPTION
        Renames or updates the description of an existing folder in the Infisical
        secrets manager. Requires the folder ID.

    .PARAMETER Id
        The ID of the folder to update. Accepts pipeline input by property name.

    .PARAMETER NewName
        The new name for the folder.

    .PARAMETER Environment
        The environment slug. Required by the API for context.

    .PARAMETER SecretPath
        The path of the folder. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Description
        An optional new description for the folder.

    .PARAMETER PassThru
        Return the updated InfisicalFolder object.

    .EXAMPLE
        Set-InfisicalFolder -Id 'folder-abc-123' -NewName 'renamed-folder'

        Renames a folder.

    .EXAMPLE
        Get-InfisicalFolder | Where-Object Name -eq 'old' | Set-InfisicalFolder -NewName 'new'

        Renames a folder found via pipeline.

    .OUTPUTS
        [InfisicalFolder] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalFolder
    .LINK
        New-InfisicalFolder
    .LINK
        Remove-InfisicalFolder
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalFolder])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $NewName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId,

        [Parameter()]
        [string] $Description,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        $session = Get-InfisicalSession

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Renaming folder '$Id' to '$NewName' at path '$SecretPath' (environment: $resolvedEnvironment)")) {
            $body = @{
                projectId   = $resolvedProjectId
                environment = $resolvedEnvironment
                name        = $NewName
                path        = $SecretPath
            }

            if ($PSBoundParameters.ContainsKey('Description')) {
                $body['description'] = $Description
            }

            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v2/folders/$Id" -Body $body -Session $session

            if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.folder) {
                return ConvertTo-InfisicalFolder -FolderData $response.folder -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
            }
        }
    }
}
