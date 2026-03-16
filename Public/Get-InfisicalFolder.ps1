# Get-InfisicalFolder.ps1
# Retrieves folders from the Infisical API.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalFolder class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalFolder {
    <#
    .SYNOPSIS
        Retrieves folders from an Infisical path.

    .DESCRIPTION
        Fetches folders from the specified Infisical environment and path. Returns
        InfisicalFolder objects. Use -Id to retrieve a specific folder by its ID.

    .PARAMETER Id
        The folder ID to retrieve. When specified, returns a single folder.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path to list folders from. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Recursive
        Include folders from sub-paths.

    .EXAMPLE
        Get-InfisicalFolder

        Returns all folders in the default environment at the root path.

    .EXAMPLE
        Get-InfisicalFolder -Environment 'staging' -SecretPath '/database'

        Returns folders under the /database path in staging.

    .EXAMPLE
        Get-InfisicalFolder -Id 'folder-abc-123'

        Returns a specific folder by ID.

    .OUTPUTS
        [InfisicalFolder] or [InfisicalFolder[]]

    .LINK
        New-InfisicalFolder
    .LINK
        Set-InfisicalFolder
    .LINK
        Remove-InfisicalFolder
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPath')]
    [OutputType([InfisicalFolder], [InfisicalFolder[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(ParameterSetName = 'ByPath')]
        [string] $Environment,

        [Parameter(ParameterSetName = 'ByPath')]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter(ParameterSetName = 'ByPath')]
        [switch] $Recursive
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v2/folders/$Id" -QueryParameters @{ projectId = $resolvedProjectId } -Session $session

        if ($null -eq $response -or $null -eq $response.folder) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new(
                    "Folder '$Id' not found."
                ),
                'InfisicalFolderNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Id
            )
            $PSCmdlet.WriteError($errorRecord)
            return
        }

        return ConvertTo-InfisicalFolder -FolderData $response.folder -Environment $resolvedEnvironment -ProjectId $resolvedProjectId
    }

    # ByPath: list folders
    $queryParams = @{
        projectId   = $resolvedProjectId
        environment = $resolvedEnvironment
        path        = $SecretPath
    }

    if ($Recursive.IsPresent) {
        $queryParams['recursive'] = 'true'
    }

    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v2/folders' -QueryParameters $queryParams -Session $session

    if ($null -eq $response -or $null -eq $response.folders) {
        return
    }

    foreach ($folderData in $response.folders) {
        ConvertTo-InfisicalFolder -FolderData $folderData -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
    }
}
