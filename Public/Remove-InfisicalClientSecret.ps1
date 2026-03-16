# Remove-InfisicalClientSecret.ps1
# Revokes a client secret for a machine identity.
# Called by: User directly. Supports pipeline input from Get-InfisicalClientSecret.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalClientSecret {
    <#
    .SYNOPSIS
        Revokes a client secret for a machine identity.

    .DESCRIPTION
        Permanently revokes the specified client secret. The identity can no longer
        authenticate using this secret. Confirms by default.

    .PARAMETER IdentityId
        The ID of the machine identity. Accepts pipeline input by property name.

    .PARAMETER Id
        The ID of the client secret to revoke. Accepts pipeline input by property name.

    .EXAMPLE
        Remove-InfisicalClientSecret -IdentityId 'identity-123' -Id 'cs-abc' -Confirm:$false

        Revokes a client secret without confirmation.

    .EXAMPLE
        Get-InfisicalClientSecret -IdentityId 'identity-123' |
            Where-Object { -not $_.IsActive } | Remove-InfisicalClientSecret

        Cleans up already-revoked client secrets via pipeline.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. The client secret is immediately invalidated.

    .LINK
        Get-InfisicalClientSecret
    .LINK
        New-InfisicalClientSecret
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    process {
        $session = Get-InfisicalSession

        if ($PSCmdlet.ShouldProcess("Revoking client secret '$Id' for identity '$IdentityId'")) {
            $body = @{
                clientSecretId = $Id
            }

            Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/auth/universal-auth/identities/$IdentityId/client-secrets/$Id/revoke" -Body $body -Session $session | Out-Null
        }
    }
}
