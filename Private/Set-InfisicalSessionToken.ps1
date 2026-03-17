# Set-InfisicalSessionToken.ps1
# Extracts the access token from an auth response and stores it in the session.
# Shared helper for all auth methods in Connect-Infisical.
# Called by: Connect-Infisical
# Dependencies: InfisicalSession class

function Set-InfisicalSessionToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Internal helper that modifies in-memory session object only')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [InfisicalSession] $Session,

        [Parameter(Mandatory)]
        [PSObject] $AuthResponse
    )

    $secureToken = [System.Security.SecureString]::new()
    foreach ($char in $AuthResponse.accessToken.ToCharArray()) {
        $secureToken.AppendChar($char)
    }
    $secureToken.MakeReadOnly()
    $Session.AccessToken = $secureToken

    $hasExpiresIn = if ($AuthResponse -is [hashtable]) { $AuthResponse.ContainsKey('expiresIn') } else { $null -ne $AuthResponse.PSObject.Properties['expiresIn'] }
    if ($hasExpiresIn -and $AuthResponse.expiresIn) {
        $Session.TokenExpiry = [datetime]::UtcNow.AddSeconds($AuthResponse.expiresIn)
    }
}
