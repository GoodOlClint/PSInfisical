# ConvertTo-InfisicalSecret.ps1
# Converts an Infisical API secret response object into an InfisicalSecret instance.
# Centralises the response-to-object mapping that was previously duplicated across
# Get-InfisicalSecret, Get-InfisicalSecrets, New-InfisicalSecret, and Set-InfisicalSecret.
# Called by: Public functions that return InfisicalSecret objects.
# Dependencies: InfisicalSecret class

function ConvertTo-InfisicalSecret {
    [CmdletBinding()]
    [OutputType([InfisicalSecret])]
    param(
        [Parameter(Mandatory)]
        [PSObject] $SecretData,

        [Parameter(Mandatory)]
        [string] $Environment,

        [Parameter(Mandatory)]
        [string] $ProjectId,

        [Parameter()]
        [string] $FallbackPath = '/'
    )

    $secret = [InfisicalSecret]::new()
    $secret.Name = $SecretData.secretKey
    $secret.Environment = $Environment
    $secret.Path = if ($SecretData.PSObject.Properties['secretPath'] -and $SecretData.secretPath) { $SecretData.secretPath } else { $FallbackPath }
    $secret.ProjectId = $ProjectId
    $secret.Version = if ($null -ne $SecretData.version) { [int]$SecretData.version } else { 0 }
    $secret.Comment = if ($SecretData.secretComment) { $SecretData.secretComment } else { '' }
    $secret.Id = if ($SecretData.id) { $SecretData.id } elseif ($SecretData._id) { $SecretData._id } else { '' }

    # Parse timestamps safely with invariant culture
    $parsedDate = [datetime]::MinValue
    if ($SecretData.createdAt -and [datetime]::TryParse($SecretData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $secret.CreatedAt = $parsedDate
    }
    if ($SecretData.updatedAt -and [datetime]::TryParse($SecretData.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $secret.UpdatedAt = $parsedDate
    }

    # Store value as SecureString
    if ($null -ne $SecretData.secretValue) {
        $secureValue = [System.Security.SecureString]::new()
        foreach ($char in $SecretData.secretValue.ToString().ToCharArray()) {
            $secureValue.AppendChar($char)
        }
        $secureValue.MakeReadOnly()
        $secret.Value = $secureValue
    }

    return $secret
}
