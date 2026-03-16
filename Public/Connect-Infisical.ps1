# Connect-Infisical.ps1
# Authenticates to the Infisical API and establishes a module-scoped session.
# Supports UniversalAuth (machine identity), static Token, and pre-obtained AccessToken.
# Called by: User directly. First command to run before any secret operations.
# Dependencies: InfisicalSession class

function Connect-Infisical {
    <#
    .SYNOPSIS
        Connects to the Infisical secrets management API.

    .DESCRIPTION
        Establishes an authenticated session to the Infisical API. Supports three
        authentication methods: UniversalAuth (machine identity with client credentials),
        Token (static API token), and AccessToken (pre-obtained JWT). The session is
        stored at module scope and used by all subsequent commands.

    .PARAMETER ClientId
        The Machine Identity Client ID for UniversalAuth authentication.

    .PARAMETER ClientSecret
        The Machine Identity Client Secret as a SecureString for UniversalAuth authentication.

    .PARAMETER Token
        A static API token as a SecureString for Token-based authentication.

    .PARAMETER AccessToken
        A pre-obtained JWT access token as a SecureString, e.g. from a CI system.

    .PARAMETER ApiUrl
        The Infisical base URL (without trailing /api). Defaults to "https://app.infisical.com".
        Use this parameter for self-hosted Infisical instances.

    .PARAMETER ProjectId
        The Infisical workspace/project ID. Required for all operations.

    .PARAMETER Environment
        The default environment slug (e.g. "dev", "staging", "prod"). Defaults to "prod".
        Can be overridden per-command.

    .PARAMETER PassThru
        If specified, returns the InfisicalSession object.

    .EXAMPLE
        $secret = Read-Host -AsSecureString -Prompt 'Client Secret'
        Connect-Infisical -ClientId 'my-client-id' -ClientSecret $secret -ProjectId 'proj-123'

        Connects using UniversalAuth machine identity credentials.

    .EXAMPLE
        $token = Read-Host -AsSecureString -Prompt 'API Token'
        Connect-Infisical -Token $token -ProjectId 'proj-123' -ApiUrl 'https://infisical.mycompany.com'

        Connects to a self-hosted Infisical instance using a static token.

    .OUTPUTS
        [InfisicalSession] when -PassThru is specified; otherwise, no output.

    .NOTES
        Client credentials are stored in the session for automatic token refresh
        when using UniversalAuth. Static tokens cannot be refreshed automatically.

    .LINK
        Disconnect-Infisical
    .LINK
        Get-InfisicalSecret
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'UniversalAuth')]
    [OutputType([InfisicalSession])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'UniversalAuth')]
        [ValidateNotNullOrEmpty()]
        [string] $ClientId,

        [Parameter(Mandatory, ParameterSetName = 'UniversalAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $ClientSecret,

        [Parameter(Mandatory, ParameterSetName = 'Token')]
        [ValidateNotNull()]
        [System.Security.SecureString] $Token,

        [Parameter(Mandatory, ParameterSetName = 'AccessToken')]
        [ValidateNotNull()]
        [System.Security.SecureString] $AccessToken,

        # AWS Auth
        [Parameter(Mandatory, ParameterSetName = 'AWSAuth')]
        [ValidateNotNullOrEmpty()]
        [string] $AWSIdentityDocument,

        # Azure Auth
        [Parameter(Mandatory, ParameterSetName = 'AzureAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $AzureJwt,

        # GCP Auth
        [Parameter(Mandatory, ParameterSetName = 'GCPAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $GCPIdentityToken,

        # Kubernetes Auth
        [Parameter(Mandatory, ParameterSetName = 'KubernetesAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $KubernetesServiceAccountToken,

        [Parameter(Mandatory, ParameterSetName = 'KubernetesAuth')]
        [ValidateNotNullOrEmpty()]
        [string] $KubernetesIdentityId,

        # OIDC Auth
        [Parameter(Mandatory, ParameterSetName = 'OIDCAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $OIDCToken,

        [Parameter(Mandatory, ParameterSetName = 'OIDCAuth')]
        [ValidateNotNullOrEmpty()]
        [string] $OIDCIdentityId,

        # JWT Auth
        [Parameter(Mandatory, ParameterSetName = 'JWTAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $Jwt,

        [Parameter(Mandatory, ParameterSetName = 'JWTAuth')]
        [ValidateNotNullOrEmpty()]
        [string] $JwtIdentityId,

        # LDAP Auth
        [Parameter(Mandatory, ParameterSetName = 'LDAPAuth')]
        [ValidateNotNullOrEmpty()]
        [string] $LDAPUsername,

        [Parameter(Mandatory, ParameterSetName = 'LDAPAuth')]
        [ValidateNotNull()]
        [System.Security.SecureString] $LDAPPassword,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ApiUrl = 'https://app.infisical.com',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string] $Environment = 'prod',

        [Parameter()]
        [switch] $PassThru
    )

    # Normalize API URL — remove trailing slash
    $ApiUrl = $ApiUrl.TrimEnd('/')

    if ($PSCmdlet.ShouldProcess("Connecting to $ApiUrl with auth method '$($PSCmdlet.ParameterSetName)'")) {
        # Dispose SecureStrings from any existing session before replacing
        if ($null -ne $script:InfisicalSession) {
            if ($null -ne $script:InfisicalSession.AccessToken) {
                $script:InfisicalSession.AccessToken.Dispose()
            }
            if ($null -ne $script:InfisicalSession.ClientSecret) {
                $script:InfisicalSession.ClientSecret.Dispose()
            }
        }
        $script:InfisicalSession = $null

        Write-Verbose "Connect-Infisical: Connecting to $ApiUrl with auth method '$($PSCmdlet.ParameterSetName)'"

        $session = [InfisicalSession]::new()
        $session.ApiUrl = $ApiUrl
        $session.ProjectId = $ProjectId
        $session.DefaultEnvironment = $Environment
        $session.AuthMethod = $PSCmdlet.ParameterSetName

        switch ($PSCmdlet.ParameterSetName) {
            'UniversalAuth' {
                # Store credentials for automatic re-auth
                $session.ClientId = $ClientId
                $session.ClientSecret = $ClientSecret

                # Authenticate via the universal-auth endpoint
                $clientSecretPlainText = [System.Net.NetworkCredential]::new('', $ClientSecret).Password
                $authBody = @{
                    clientId     = $ClientId
                    clientSecret = $clientSecretPlainText
                }
                $bodyJson = $authBody | ConvertTo-Json -Compress
                $authUri = "$ApiUrl/api/v1/auth/universal-auth/login"

                Write-Verbose "Connect-Infisical: Authenticating via POST $authUri"

                try {
                    $authResponse = Invoke-RestMethod -Uri $authUri -Method POST -Body $bodyJson -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop
                }
                catch {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Security.Authentication.AuthenticationException]::new(
                            "UniversalAuth login failed: $($_.Exception.Message)"
                        ),
                        'InfisicalUniversalAuthFailed',
                        [System.Management.Automation.ErrorCategory]::AuthenticationError,
                        $authUri
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                # Validate response contains an access token
                if (-not $authResponse -or [string]::IsNullOrEmpty($authResponse.accessToken)) {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Security.Authentication.AuthenticationException]::new(
                            'UniversalAuth login succeeded but the response did not contain an access token.'
                        ),
                        'InfisicalUniversalAuthNoToken',
                        [System.Management.Automation.ErrorCategory]::AuthenticationError,
                        $authUri
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                # Store token as SecureString
                $secureToken = [System.Security.SecureString]::new()
                foreach ($char in $authResponse.accessToken.ToCharArray()) {
                    $secureToken.AppendChar($char)
                }
                $secureToken.MakeReadOnly()
                $session.AccessToken = $secureToken

                if ($authResponse.expiresIn) {
                    $session.TokenExpiry = [datetime]::UtcNow.AddSeconds($authResponse.expiresIn)
                }

                # Clear auth response to reduce plaintext token exposure window
                $authResponse = $null

                Write-Verbose "Connect-Infisical: UniversalAuth authentication successful."
            }
            'Token' {
                $session.AccessToken = $Token
                # Static tokens do not have a known expiry
                $session.TokenExpiry = $null
            }
            'AccessToken' {
                $session.AccessToken = $AccessToken
                # Pre-obtained JWTs may expire, but we don't know when without decoding
                $session.TokenExpiry = $null
            }
            'AWSAuth' {
                $authBody = @{ iamHttpRequestMethod = 'POST'; iamRequestBody = $AWSIdentityDocument }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'aws-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
            'AzureAuth' {
                $jwt = [System.Net.NetworkCredential]::new('', $AzureJwt).Password
                $authBody = @{ jwt = $jwt }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'azure-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
            'GCPAuth' {
                $token = [System.Net.NetworkCredential]::new('', $GCPIdentityToken).Password
                $authBody = @{ jwt = $token }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'gcp-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
            'KubernetesAuth' {
                $saToken = [System.Net.NetworkCredential]::new('', $KubernetesServiceAccountToken).Password
                $authBody = @{ jwt = $saToken; identityId = $KubernetesIdentityId }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'kubernetes-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
            'OIDCAuth' {
                $oidcJwt = [System.Net.NetworkCredential]::new('', $OIDCToken).Password
                $authBody = @{ jwt = $oidcJwt; identityId = $OIDCIdentityId }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'oidc-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
            'JWTAuth' {
                $jwtValue = [System.Net.NetworkCredential]::new('', $Jwt).Password
                $authBody = @{ jwt = $jwtValue; identityId = $JwtIdentityId }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'jwt-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
            'LDAPAuth' {
                $ldapPass = [System.Net.NetworkCredential]::new('', $LDAPPassword).Password
                $authBody = @{ username = $LDAPUsername; password = $ldapPass }
                $authResponse = Invoke-InfisicalAuthEndpoint -ApiUrl $ApiUrl -AuthPath 'ldap-auth' -Body $authBody -CallerCmdlet $PSCmdlet
                Set-InfisicalSessionToken -Session $session -AuthResponse $authResponse
                $authResponse = $null
            }
        }

        $session.UpdateConnectionStatus()
        $script:InfisicalSession = $session

        # Probe server API capabilities for version gating
        Write-Verbose 'Connect-Infisical: Probing server API capabilities...'
        try {
            $session.ApiCapabilities = Test-InfisicalApiCapability -Session $session
        }
        catch {
            Write-Warning "Connect-Infisical: Unable to detect server API capabilities: $($_.Exception.Message). Version checks will be skipped."
            $session.ApiCapabilities = @{}
        }

        Write-Verbose "Connect-Infisical: Session established. Connected=$($session.Connected)"

        if ($PassThru.IsPresent) {
            return $session
        }
    }
}
