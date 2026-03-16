# New-InfisicalClientSecret.ps1
# Generates a client secret for a machine identity's Universal Auth.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalClientSecret {
    <#
    .SYNOPSIS
        Generates a client secret for a machine identity.

    .DESCRIPTION
        Creates a new client secret for the specified identity's Universal Auth
        configuration. The secret value is only returned once - store it securely.

    .PARAMETER IdentityId
        The ID of the machine identity.

    .PARAMETER Description
        An optional description for the client secret.

    .PARAMETER TTL
        Lifetime of the client secret in seconds. 0 = never expires. Default: 0.

    .PARAMETER NumUsesLimit
        Maximum number of times the secret can be used. 0 = unlimited. Default: 0.

    .EXAMPLE
        New-InfisicalClientSecret -IdentityId 'identity-123'

        Generates a client secret with no expiry or use limit.

    .EXAMPLE
        $cred = New-InfisicalClientSecret -IdentityId 'identity-123' -Description 'CI runner' -TTL 86400
        $cred.clientSecret  # Store this immediately - shown only once

        Generates a client secret with 24-hour TTL.

    .OUTPUTS
        PSCustomObject with clientSecret, clientSecretId, and other properties.
        The clientSecret value is only available in this response.

    .LINK
        Add-InfisicalIdentityAuth
    .LINK
        Get-InfisicalIdentity
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter()]
        [string] $Description,

        [Parameter()]
        [ValidateRange(0, 315360000)]
        [int] $TTL = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $NumUsesLimit = 0
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Generating client secret for identity '$IdentityId'")) {
        $body = @{
            ttl           = $TTL
            numUsesLimit  = $NumUsesLimit
        }

        if (-not [string]::IsNullOrEmpty($Description)) {
            $body['description'] = $Description
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/auth/universal-auth/identities/$IdentityId/client-secrets" -Body $body -Session $session

        return $response
    }
}
