# Get-InfisicalClientSecret.ps1
# Lists client secrets for a machine identity's Universal Auth.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalClientSecret {
    <#
    .SYNOPSIS
        Lists client secrets for a machine identity.

    .DESCRIPTION
        Retrieves all client secrets configured for the specified identity's
        Universal Auth. Note: the actual secret values are not returned, only
        metadata (ID, description, creation date, usage count, etc.).

    .PARAMETER IdentityId
        The ID of the machine identity.

    .EXAMPLE
        Get-InfisicalClientSecret -IdentityId 'identity-123'

        Lists all client secrets for the identity.

    .OUTPUTS
        PSCustomObject[] with client secret metadata.

    .LINK
        New-InfisicalClientSecret
    .LINK
        Remove-InfisicalClientSecret
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId
    )

    $session = Get-InfisicalSession

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/auth/universal-auth/identities/$IdentityId/client-secrets" -Session $session

    if ($null -eq $response -or $null -eq $response.clientSecretData) {
        return
    }

    foreach ($cs in $response.clientSecretData) {
        $id = if ($cs -is [hashtable]) { $cs['id'] } else { $cs.id }
        $desc = if ($cs -is [hashtable] -and $cs.ContainsKey('description')) { $cs['description'] } elseif ($cs -isnot [hashtable] -and $cs.description) { $cs.description } else { '' }
        $isActive = if ($cs -is [hashtable] -and $cs.ContainsKey('isClientSecretRevoked')) { -not $cs['isClientSecretRevoked'] } elseif ($cs -isnot [hashtable]) { -not $cs.isClientSecretRevoked } else { $true }

        $createdAt = [datetime]::MinValue
        if ($cs.createdAt) { [void][datetime]::TryParse($cs.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }

        [PSCustomObject]@{
            PSTypeName   = 'InfisicalClientSecret'
            Id           = $id
            Description  = $desc
            IsActive     = $isActive
            IdentityId   = $IdentityId
            CreatedAt    = $createdAt
        }
    }
}
