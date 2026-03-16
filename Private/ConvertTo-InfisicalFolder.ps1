# ConvertTo-InfisicalFolder.ps1
# Converts an Infisical API folder response object into an InfisicalFolder instance.
# Called by: Public folder functions that return InfisicalFolder objects.
# Dependencies: InfisicalFolder class

function ConvertTo-InfisicalFolder {
    [CmdletBinding()]
    [OutputType([InfisicalFolder])]
    param(
        [Parameter(Mandatory)]
        [PSObject] $FolderData,

        [Parameter(Mandatory)]
        [string] $Environment,

        [Parameter(Mandatory)]
        [string] $ProjectId,

        [Parameter()]
        [string] $FallbackPath = '/'
    )

    $folder = [InfisicalFolder]::new()

    $folder.Id = if ($FolderData -is [hashtable]) {
        if ($FolderData.ContainsKey('id')) { $FolderData['id'] } else { '' }
    } else {
        if ($FolderData.id) { $FolderData.id } else { '' }
    }

    $folder.Name = if ($FolderData -is [hashtable]) { $FolderData['name'] } else { $FolderData.name }
    $folder.Environment = $Environment
    $folder.ProjectId = $ProjectId

    # Path from response or fallback
    $hasPath = if ($FolderData -is [hashtable]) { $FolderData.ContainsKey('path') } else { $null -ne $FolderData.PSObject.Properties['path'] }
    $folder.Path = if ($hasPath -and $FolderData.path) { $FolderData.path } else { $FallbackPath }

    # Description
    $hasDesc = if ($FolderData -is [hashtable]) { $FolderData.ContainsKey('description') } else { $null -ne $FolderData.PSObject.Properties['description'] }
    $folder.Description = if ($hasDesc -and $FolderData.description) { $FolderData.description } else { '' }

    # Parse timestamps safely with invariant culture
    $parsedDate = [datetime]::MinValue
    if ($FolderData.createdAt -and [datetime]::TryParse($FolderData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $folder.CreatedAt = $parsedDate
    }
    if ($FolderData.updatedAt -and [datetime]::TryParse($FolderData.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $folder.UpdatedAt = $parsedDate
    }

    return $folder
}
