# Get-InfisicalProject.ps1
# Retrieves projects/workspaces from Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalProject {
    <#
    .SYNOPSIS
        Retrieves projects from Infisical.

    .DESCRIPTION
        Lists projects accessible to the current identity, or retrieves a specific
        project by ID. Useful for discovery workflows and validating project IDs.

    .PARAMETER Id
        The project/workspace ID to retrieve. When specified, returns a single project.

    .EXAMPLE
        Get-InfisicalProject

        Returns all projects accessible to the current identity.

    .EXAMPLE
        Get-InfisicalProject -Id 'proj-abc-123'

        Returns a specific project by ID.

    .OUTPUTS
        PSCustomObject with Id, Name, Slug, CreatedAt, and UpdatedAt properties.

    .LINK
        Get-InfisicalEnvironment
    .LINK
        Connect-Infisical
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v2/workspace/$Id" -Session $session

        if ($null -eq $response -or $null -eq $response.workspace) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Project '$Id' not found."),
                'InfisicalProjectNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Id
            )
            $PSCmdlet.WriteError($errorRecord)
            return
        }

        return ConvertTo-InfisicalProjectObject -Data $response.workspace
    }

    # List all projects
    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v2/workspace' -Session $session

    if ($null -eq $response -or $null -eq $response.workspaces) {
        return
    }

    foreach ($ws in $response.workspaces) {
        ConvertTo-InfisicalProjectObject -Data $ws
    }
}

function ConvertTo-InfisicalProjectObject {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [PSObject] $Data)

    $id = if ($Data -is [hashtable]) { $Data['id'] } else { $Data.id }
    $name = if ($Data -is [hashtable]) { $Data['name'] } else { $Data.name }
    $slug = if ($Data -is [hashtable] -and $Data.ContainsKey('slug')) { $Data['slug'] } elseif ($Data -isnot [hashtable] -and $Data.slug) { $Data.slug } else { '' }

    $createdAt = [datetime]::MinValue
    $updatedAt = [datetime]::MinValue
    if ($Data.createdAt) { [void][datetime]::TryParse($Data.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }
    if ($Data.updatedAt) { [void][datetime]::TryParse($Data.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$updatedAt) }

    [PSCustomObject]@{
        PSTypeName = 'InfisicalProject'
        Id         = $id
        Name       = $name
        Slug       = $slug
        CreatedAt  = $createdAt
        UpdatedAt  = $updatedAt
    }
}
