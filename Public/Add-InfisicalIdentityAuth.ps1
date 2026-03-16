# Add-InfisicalIdentityAuth.ps1
# Attaches an authentication method to a machine identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Add-InfisicalIdentityAuth {
    <#
    .SYNOPSIS
        Attaches an authentication method to a machine identity.

    .DESCRIPTION
        Configures Universal Auth on a machine identity, enabling it to authenticate
        with client credentials. After attaching, use New-InfisicalClientSecret to
        generate credentials.

    .PARAMETER IdentityId
        The ID of the machine identity to attach authentication to.

    .PARAMETER AccessTokenTTL
        Access token lifetime in seconds. Default: 2592000 (30 days). Max: 315360000 (10 years).

    .PARAMETER AccessTokenMaxTTL
        Maximum access token lifetime in seconds. Default: 2592000.

    .PARAMETER AccessTokenNumUsesLimit
        Maximum number of times a token can be used. 0 = unlimited. Default: 0.

    .PARAMETER ClientSecretTrustedIps
        Array of IP addresses or CIDR ranges allowed to use client secrets.

    .PARAMETER AccessTokenTrustedIps
        Array of IP addresses or CIDR ranges allowed to use access tokens.

    .PARAMETER PassThru
        Return the auth configuration as a PSCustomObject.

    .EXAMPLE
        Add-InfisicalIdentityAuth -IdentityId 'identity-123'

        Attaches Universal Auth with default settings.

    .EXAMPLE
        Add-InfisicalIdentityAuth -IdentityId 'identity-123' -AccessTokenTTL 3600 -PassThru

        Attaches Universal Auth with 1-hour token TTL and returns the config.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        New-InfisicalClientSecret
    .LINK
        Get-InfisicalIdentityAuth
    .LINK
        Remove-InfisicalIdentityAuth
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter()]
        [ValidateRange(0, 315360000)]
        [int] $AccessTokenTTL,

        [Parameter()]
        [ValidateRange(0, 315360000)]
        [int] $AccessTokenMaxTTL,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $AccessTokenNumUsesLimit,

        [Parameter()]
        [string[]] $ClientSecretTrustedIps,

        [Parameter()]
        [string[]] $AccessTokenTrustedIps,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Attaching Universal Auth to identity '$IdentityId'")) {
        $body = @{}

        if ($PSBoundParameters.ContainsKey('AccessTokenTTL'))          { $body['accessTokenTTL'] = $AccessTokenTTL }
        if ($PSBoundParameters.ContainsKey('AccessTokenMaxTTL'))       { $body['accessTokenMaxTTL'] = $AccessTokenMaxTTL }
        if ($PSBoundParameters.ContainsKey('AccessTokenNumUsesLimit')) { $body['accessTokenNumUsesLimit'] = $AccessTokenNumUsesLimit }

        if ($null -ne $ClientSecretTrustedIps -and $ClientSecretTrustedIps.Count -gt 0) {
            $body['clientSecretTrustedIps'] = @($ClientSecretTrustedIps | ForEach-Object { @{ ipAddress = $_ } })
        }
        if ($null -ne $AccessTokenTrustedIps -and $AccessTokenTrustedIps.Count -gt 0) {
            $body['accessTokenTrustedIps'] = @($AccessTokenTrustedIps | ForEach-Object { @{ ipAddress = $_ } })
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/auth/universal-auth/identities/$IdentityId" -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response) {
            return $response
        }
    }
}
