# ConvertTo-InfisicalTag.ps1
# Converts an Infisical API tag response object into an InfisicalTag instance.
# Called by: Public tag functions that return InfisicalTag objects.
# Dependencies: InfisicalTag class

function ConvertTo-InfisicalTag {
    [CmdletBinding()]
    [OutputType([InfisicalTag])]
    param(
        [Parameter(Mandatory)]
        [PSObject] $TagData,

        [Parameter(Mandatory)]
        [string] $ProjectId
    )

    $tag = [InfisicalTag]::new()

    $tag.Id = if ($TagData -is [hashtable]) {
        if ($TagData.ContainsKey('id')) { $TagData['id'] } else { '' }
    } else {
        if ($TagData.id) { $TagData.id } else { '' }
    }

    $tag.Name = if ($TagData -is [hashtable]) { $TagData['name'] } else { $TagData.name }
    $tag.Slug = if ($TagData -is [hashtable]) { $TagData['slug'] } else { $TagData.slug }
    $tag.Color = if ($TagData -is [hashtable]) { $TagData['color'] } else { $TagData.color }
    $tag.ProjectId = $ProjectId

    $parsedDate = [datetime]::MinValue
    if ($TagData.createdAt -and [datetime]::TryParse($TagData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $tag.CreatedAt = $parsedDate
    }
    if ($TagData.updatedAt -and [datetime]::TryParse($TagData.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $tag.UpdatedAt = $parsedDate
    }

    return $tag
}
