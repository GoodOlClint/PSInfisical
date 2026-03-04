# Get-InfisicalSecretVersion.ps1
# Lists version history for a specific secret.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalSecretVersion {
    <#
    .SYNOPSIS
        Lists version history for a secret in Infisical.

    .DESCRIPTION
        Retrieves past versions of a specific secret by querying the Infisical API
        with version parameters. Returns version objects with CreatedAt, Version number,
        and Value (as SecureString).

    .PARAMETER Name
        The name (key) of the secret to get version history for.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Limit
        Maximum number of versions to return. Defaults to 10, maximum 100.
        Each version requires a separate API call, so higher limits increase
        latency and may trigger rate limiting.

    .EXAMPLE
        Get-InfisicalSecretVersion -Name 'DATABASE_URL'

        Returns up to 10 versions of the DATABASE_URL secret.

    .EXAMPLE
        Get-InfisicalSecretVersion 'API_KEY' -Limit 5

        Returns the last 5 versions of the API_KEY secret.

    .OUTPUTS
        PSCustomObject with Version, Value (SecureString), and CreatedAt properties.

    .NOTES
        Version values are returned as SecureString for consistency with the module's
        security model. Use [System.Net.NetworkCredential]::new('', $v.Value).Password
        to retrieve plaintext values when needed.

    .LINK
        Get-InfisicalSecret
    .LINK
        Set-InfisicalSecret
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int] $Limit = 10
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    # Fetch the current secret first to determine the current version number
    $queryParams = @{
        workspaceId = $resolvedProjectId
        environment = $resolvedEnvironment
        secretPath  = $SecretPath
    }

    $encodedName = [System.Uri]::EscapeDataString($Name)
    $currentResponse = Invoke-InfisicalApi -Method GET -Endpoint "/api/v3/secrets/raw/$encodedName" -QueryParameters $queryParams -Session $session

    if ($null -eq $currentResponse -or $null -eq $currentResponse.secret) {
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

    $currentVersion = [int]$currentResponse.secret.version
    $versionsToFetch = [math]::Min($Limit, $currentVersion)

    # Retrieve each version by specifying the version query parameter
    for ($v = $currentVersion; $v -gt ($currentVersion - $versionsToFetch); $v--) {
        $versionParams = @{
            workspaceId = $resolvedProjectId
            environment = $resolvedEnvironment
            secretPath  = $SecretPath
            version     = $v
        }

        $versionResponse = Invoke-InfisicalApi -Method GET -Endpoint "/api/v3/secrets/raw/$encodedName" -QueryParameters $versionParams -Session $session

        if ($null -ne $versionResponse -and $null -ne $versionResponse.secret) {
            $secretData = $versionResponse.secret

            $secureValue = $null
            if ($null -ne $secretData.secretValue) {
                $secureValue = [System.Security.SecureString]::new()
                foreach ($char in $secretData.secretValue.ToString().ToCharArray()) {
                    $secureValue.AppendChar($char)
                }
                $secureValue.MakeReadOnly()
            }

            $createdAt = [datetime]::MinValue
            if ($secretData.createdAt) {
                [void][datetime]::TryParse($secretData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt)
            }

            [PSCustomObject]@{
                PSTypeName = 'InfisicalSecretVersion'
                Name       = $secretData.secretKey
                Version    = [int]$secretData.version
                Value      = $secureValue
                CreatedAt  = $createdAt
            }
        }
    }
}
