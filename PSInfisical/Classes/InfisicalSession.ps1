# InfisicalSession.ps1
# Defines the InfisicalSession class used to store authentication state and connection details.
# Used by: Connect-Infisical, Get-InfisicalSession, all public functions via session validation.
# Dependencies: None

class InfisicalSession {
    [string] $ApiUrl
    [string] $ProjectId
    [string] $DefaultEnvironment
    [System.Security.SecureString] $AccessToken
    [Nullable[datetime]] $TokenExpiry
    [string] $AuthMethod          # UniversalAuth, Token, AccessToken
    [string] $ClientId            # Stored for re-auth (UniversalAuth only)
    [System.Security.SecureString] $ClientSecret  # Stored for re-auth (UniversalAuth only)

    [bool] $Connected

    InfisicalSession() {
        $this.DefaultEnvironment = 'prod'
        $this.Connected = $false
    }

    # Update Connected based on token state
    [void] UpdateConnectionStatus() {
        if ($null -eq $this.AccessToken) {
            $this.Connected = $false
            return
        }
        if ($null -ne $this.TokenExpiry -and $this.TokenExpiry -le [datetime]::UtcNow) {
            $this.Connected = $false
            return
        }
        $this.Connected = $true
    }

    [bool] IsTokenExpiringSoon() {
        if ($null -eq $this.TokenExpiry) {
            return $false
        }
        return ($this.TokenExpiry -le [datetime]::UtcNow.AddSeconds(60))
    }

    [bool] CanReauthenticate() {
        return ($this.AuthMethod -eq 'UniversalAuth' -and
                -not [string]::IsNullOrEmpty($this.ClientId) -and
                $null -ne $this.ClientSecret)
    }

    [string] GetAccessTokenPlainText() {
        if ($null -eq $this.AccessToken) {
            return $null
        }
        return [System.Net.NetworkCredential]::new('', $this.AccessToken).Password
    }

    [string] ToString() {
        $this.UpdateConnectionStatus()
        return "InfisicalSession: ApiUrl=$($this.ApiUrl), ProjectId=$($this.ProjectId), AuthMethod=$($this.AuthMethod), Connected=$($this.Connected)"
    }
}
