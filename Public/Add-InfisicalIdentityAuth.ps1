# Add-InfisicalIdentityAuth.ps1
# Attaches an authentication method to a machine identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Add-InfisicalIdentityAuth {
    <#
    .SYNOPSIS
        Attaches an authentication method to a machine identity.

    .DESCRIPTION
        Configures an authentication method on a machine identity, enabling it to
        authenticate via the specified method. All auth methods support access token
        TTL and IP restriction settings. Method-specific parameters are passed via
        -AuthParameters.

    .PARAMETER IdentityId
        The ID of the machine identity to attach authentication to.

    .PARAMETER AuthMethod
        The authentication method to attach. Defaults to 'universal-auth'.

    .PARAMETER AccessTokenTTL
        Access token lifetime in seconds. Default: 2592000 (30 days). Max: 315360000 (10 years).

    .PARAMETER AccessTokenMaxTTL
        Maximum access token lifetime in seconds. Default: 2592000.

    .PARAMETER AccessTokenNumUsesLimit
        Maximum number of times a token can be used. 0 = unlimited. Default: 0.

    .PARAMETER AccessTokenTrustedIps
        Array of IP addresses or CIDR ranges allowed to use access tokens.

    .PARAMETER AuthParameters
        A hashtable of method-specific parameters. For example, for kubernetes-auth:
        @{ kubernetesHost = 'https://k8s.local'; tokenReviewerJwt = '...' }
        For aws-auth: @{ allowedAccountIds = @('123456789') }

    .PARAMETER PassThru
        Return the auth configuration as a PSCustomObject.

    .EXAMPLE
        Add-InfisicalIdentityAuth -IdentityId 'identity-123'

        Attaches Universal Auth with default settings.

    .EXAMPLE
        Add-InfisicalIdentityAuth -IdentityId 'identity-123' -AuthMethod 'kubernetes-auth' `
            -AuthParameters @{ kubernetesHost = 'https://k8s.local' } -PassThru

        Attaches Kubernetes Auth with custom settings.

    .EXAMPLE
        Add-InfisicalIdentityAuth -IdentityId 'identity-123' -AuthMethod 'aws-auth' `
            -AuthParameters @{ allowedAccountIds = @('123456789012') }

        Attaches AWS Auth restricted to a specific account.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalIdentityAuth
    .LINK
        Remove-InfisicalIdentityAuth
    .LINK
        New-InfisicalClientSecret
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter()]
        [ValidateSet('universal-auth', 'aws-auth', 'azure-auth', 'gcp-auth', 'kubernetes-auth', 'oidc-auth', 'jwt-auth', 'ldap-auth')]
        [string] $AuthMethod = 'universal-auth',

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
        [string[]] $AccessTokenTrustedIps,

        [Parameter()]
        [hashtable] $AuthParameters,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Attaching '$AuthMethod' to identity '$IdentityId'")) {
        $body = @{}

        if ($PSBoundParameters.ContainsKey('AccessTokenTTL'))          { $body['accessTokenTTL'] = $AccessTokenTTL }
        if ($PSBoundParameters.ContainsKey('AccessTokenMaxTTL'))       { $body['accessTokenMaxTTL'] = $AccessTokenMaxTTL }
        if ($PSBoundParameters.ContainsKey('AccessTokenNumUsesLimit')) { $body['accessTokenNumUsesLimit'] = $AccessTokenNumUsesLimit }

        if ($null -ne $AccessTokenTrustedIps -and $AccessTokenTrustedIps.Count -gt 0) {
            $body['accessTokenTrustedIps'] = @($AccessTokenTrustedIps | ForEach-Object { @{ ipAddress = $_ } })
        }

        # Merge method-specific parameters
        if ($null -ne $AuthParameters) {
            foreach ($key in $AuthParameters.Keys) {
                $body[$key] = $AuthParameters[$key]
            }
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/auth/$AuthMethod/identities/$IdentityId" -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response) {
            return $response
        }
    }
}
