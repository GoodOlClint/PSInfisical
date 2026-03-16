# ConvertTo-InfisicalSecretImport.ps1
# Converts an Infisical API secret import response into an InfisicalSecretImport instance.
# Called by: Public secret import functions.
# Dependencies: InfisicalSecretImport class

function ConvertTo-InfisicalSecretImport {
    [CmdletBinding()]
    [OutputType([InfisicalSecretImport])]
    param(
        [Parameter(Mandatory)]
        [PSObject] $ImportData,

        [Parameter(Mandatory)]
        [string] $ProjectId,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [string] $Path = '/'
    )

    $import = [InfisicalSecretImport]::new()

    $import.Id = if ($ImportData -is [hashtable]) {
        if ($ImportData.ContainsKey('id')) { $ImportData['id'] } else { '' }
    } else {
        if ($ImportData.id) { $ImportData.id } else { '' }
    }

    $import.ProjectId = $ProjectId
    $import.Environment = $Environment
    $import.Path = $Path

    # Source environment from importEnv object or direct field
    $hasImportEnv = if ($ImportData -is [hashtable]) { $ImportData.ContainsKey('importEnv') } else { $null -ne $ImportData.PSObject.Properties['importEnv'] }
    if ($hasImportEnv -and $null -ne $ImportData.importEnv) {
        $importEnv = $ImportData.importEnv
        $import.SourceEnvironment = if ($importEnv -is [hashtable]) { $importEnv['slug'] } else { $importEnv.slug }
    }

    # Source path from importPath
    $hasImportPath = if ($ImportData -is [hashtable]) { $ImportData.ContainsKey('importPath') } else { $null -ne $ImportData.PSObject.Properties['importPath'] }
    $import.SourcePath = if ($hasImportPath -and $ImportData.importPath) { $ImportData.importPath } else { '/' }

    # Position
    $import.Position = if ($null -ne $ImportData.position) { [int]$ImportData.position } else { 0 }

    # IsReplication
    $hasRepl = if ($ImportData -is [hashtable]) { $ImportData.ContainsKey('isReplication') } else { $null -ne $ImportData.PSObject.Properties['isReplication'] }
    $import.IsReplication = if ($hasRepl) { [bool]$ImportData.isReplication } else { $false }

    # Timestamps
    $parsedDate = [datetime]::MinValue
    if ($ImportData.createdAt -and [datetime]::TryParse($ImportData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $import.CreatedAt = $parsedDate
    }
    if ($ImportData.updatedAt -and [datetime]::TryParse($ImportData.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $import.UpdatedAt = $parsedDate
    }

    return $import
}
