# ConvertTo-InfisicalBody.ps1
# Builds request body hashtables consistently for Infisical API calls.
# Ensures workspaceId, environment, and secretPath are always included.
# Handles SecureString → plaintext conversion in a single controlled place.
# Called by: New-InfisicalSecret, Set-InfisicalSecret, Remove-InfisicalSecret
# Dependencies: InfisicalSession class

function ConvertTo-InfisicalBody {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [InfisicalSession] $Session,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [System.Security.SecureString] $SecretValue,

        [Parameter()]
        [string] $Comment,

        [Parameter()]
        [switch] $SkipMultilineEncoding,

        [Parameter()]
        [hashtable] $AdditionalProperties
    )

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) {
        $Session.DefaultEnvironment
    }
    else {
        $Environment
    }

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) {
        $Session.ProjectId
    }
    else {
        $ProjectId
    }

    $body = @{
        workspaceId = $resolvedProjectId
        environment = $resolvedEnvironment
        secretPath  = $SecretPath
    }

    # Convert SecureString to plaintext in this single controlled location
    if ($null -ne $SecretValue) {
        $body['secretValue'] = [System.Net.NetworkCredential]::new('', $SecretValue).Password
    }

    if (-not [string]::IsNullOrEmpty($Comment)) {
        $body['secretComment'] = $Comment
    }

    if ($SkipMultilineEncoding.IsPresent) {
        $body['skipMultilineEncoding'] = $true
    }

    # Merge any additional properties
    if ($null -ne $AdditionalProperties) {
        foreach ($key in $AdditionalProperties.Keys) {
            $body[$key] = $AdditionalProperties[$key]
        }
    }

    return $body
}
