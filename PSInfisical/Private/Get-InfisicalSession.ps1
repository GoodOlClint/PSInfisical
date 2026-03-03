# Get-InfisicalSession.ps1
# Retrieves and validates the current module-scoped InfisicalSession.
# Checks for token expiry and performs automatic re-authentication when possible.
# Called by: All public functions that require an active session.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi (for re-auth)

function Get-InfisicalSession {
    [CmdletBinding()]
    [OutputType([InfisicalSession])]
    param()

    $session = $script:InfisicalSession

    if ($null -eq $session) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new(
                'Not connected to Infisical. Run Connect-Infisical first.'
            ),
            'InfisicalNotConnected',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    # Check token expiry
    if ($session.IsTokenExpiringSoon()) {
        if ($session.CanReauthenticate()) {
            Write-Verbose 'Get-InfisicalSession: Token expiring soon, re-authenticating with UniversalAuth credentials.'
            try {
                $clientSecretPlainText = [System.Net.NetworkCredential]::new('', $session.ClientSecret).Password
                $authBody = @{
                    clientId     = $session.ClientId
                    clientSecret = $clientSecretPlainText
                }
                $bodyJson = $authBody | ConvertTo-Json -Compress
                $authUri = "$($session.ApiUrl.TrimEnd('/'))/api/v1/auth/universal-auth/login"

                $authResponse = Invoke-RestMethod -Uri $authUri -Method POST -Body $bodyJson -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop

                if (-not $authResponse -or [string]::IsNullOrEmpty($authResponse.accessToken)) {
                    throw [System.InvalidOperationException]::new('Re-authentication response did not contain an access token.')
                }

                $secureToken = [System.Security.SecureString]::new()
                foreach ($char in $authResponse.accessToken.ToCharArray()) {
                    $secureToken.AppendChar($char)
                }
                $secureToken.MakeReadOnly()

                # Dispose old token before replacing
                if ($null -ne $session.AccessToken) {
                    $session.AccessToken.Dispose()
                }
                $session.AccessToken = $secureToken
                if ($authResponse.expiresIn) {
                    $session.TokenExpiry = [datetime]::UtcNow.AddSeconds($authResponse.expiresIn)
                }
                $session.UpdateConnectionStatus()
                Write-Verbose 'Get-InfisicalSession: Re-authentication successful.'
            }
            catch {
                Write-Warning "Automatic re-authentication failed: $($_.Exception.Message). Run Connect-Infisical to re-authenticate manually."
            }
        }
        else {
            Write-Warning 'Infisical access token is expiring soon and automatic re-authentication is not available for this auth method. Run Connect-Infisical to refresh your session.'
        }
    }

    $session.UpdateConnectionStatus()

    if (-not $session.Connected) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new(
                'Infisical session token has expired. Run Connect-Infisical to re-authenticate.'
            ),
            'InfisicalSessionExpired',
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $null
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $session
}
