# InfisicalSecret.ps1
# Defines the InfisicalSecret class used as the standard output type for secret operations.
# Used by: Get-InfisicalSecret, Get-InfisicalSecrets, New-InfisicalSecret, Set-InfisicalSecret
# Dependencies: None

class InfisicalSecret {
    [string] $Name
    [System.Security.SecureString] $Value
    [string] $Environment
    [string] $Path
    [string] $ProjectId
    [int] $Version
    [string] $Comment
    [datetime] $CreatedAt
    [datetime] $UpdatedAt
    [string] $Id

    InfisicalSecret() { }

    # Decrypts and returns the plaintext value. Use with care — the plaintext
    # string will remain in managed memory until garbage collected.
    [string] GetValue() {
        if ($null -eq $this.Value) {
            return $null
        }
        return [System.Net.NetworkCredential]::new('', $this.Value).Password
    }

    # Safe display that never leaks the secret value.
    [string] ToString() {
        return "$($this.Name)=<value hidden>"
    }
}
