# Get-InfisicalSecret.ps1
# Retrieves a single secret by name from the Infisical API.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalSecret {
    <#
    .SYNOPSIS
        Retrieves a single secret by name from Infisical.

    .DESCRIPTION
        Fetches a specific secret from the Infisical secrets manager by its name.
        Returns an InfisicalSecret object by default with the value stored as SecureString.
        Use -Raw to get the plaintext string value directly for script interpolation.

    .PARAMETER Name
        The name (key) of the secret to retrieve.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Raw
        Return just the plaintext string value instead of an InfisicalSecret object.

    .EXAMPLE
        Get-InfisicalSecret -Name 'DATABASE_URL'

        Returns an InfisicalSecret object for the DATABASE_URL secret.

    .EXAMPLE
        Get-InfisicalSecret 'API_KEY' -Raw

        Returns the plaintext value of the API_KEY secret as a string.

    .OUTPUTS
        [InfisicalSecret] by default, or [string] when -Raw is specified.

    .NOTES
        Secret values are returned as SecureString by default. Use the GetValue() method
        or -Raw switch to access the plaintext value. Be mindful that plaintext strings
        remain in managed memory until garbage collected.

    .LINK
        Get-InfisicalSecrets
    .LINK
        New-InfisicalSecret
    .LINK
        Set-InfisicalSecret
    #>
    [CmdletBinding()]
    [OutputType([InfisicalSecret], [string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $Raw
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    $queryParams = @{
        workspaceId = $resolvedProjectId
        environment = $resolvedEnvironment
        secretPath  = $SecretPath
    }

    $encodedName = [System.Uri]::EscapeDataString($Name)
    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v3/secrets/raw/$encodedName" -QueryParameters $queryParams -Session $session

    if ($null -eq $response -or $null -eq $response.secret) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Management.Automation.ItemNotFoundException]::new(
                "Secret '$Name' not found in environment '$resolvedEnvironment' at path '$SecretPath'."
            ),
            'InfisicalSecretNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $Name
        )
        $PSCmdlet.WriteError($errorRecord)
        return
    }

    $secretData = $response.secret

    if ($Raw.IsPresent) {
        return $secretData.secretValue
    }

    $secret = [InfisicalSecret]::new()
    $secret.Name = $secretData.secretKey
    $secret.Environment = $resolvedEnvironment
    $secret.Path = if ($secretData.PSObject.Properties['secretPath'] -and $secretData.secretPath) { $secretData.secretPath } else { $SecretPath }
    $secret.ProjectId = $resolvedProjectId
    $secret.Version = if ($null -ne $secretData.version) { [int]$secretData.version } else { 0 }
    $secret.Comment = if ($secretData.secretComment) { $secretData.secretComment } else { '' }
    $secret.Id = if ($secretData.id) { $secretData.id } elseif ($secretData._id) { $secretData._id } else { '' }

    # Parse timestamps safely with invariant culture
    $parsedDate = [datetime]::MinValue
    if ($secretData.createdAt -and [datetime]::TryParse($secretData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $secret.CreatedAt = $parsedDate
    }
    if ($secretData.updatedAt -and [datetime]::TryParse($secretData.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $secret.UpdatedAt = $parsedDate
    }

    # Store value as SecureString
    if ($null -ne $secretData.secretValue) {
        $secureValue = [System.Security.SecureString]::new()
        foreach ($char in $secretData.secretValue.ToString().ToCharArray()) {
            $secureValue.AppendChar($char)
        }
        $secureValue.MakeReadOnly()
        $secret.Value = $secureValue
    }

    return $secret
}
