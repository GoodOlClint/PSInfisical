# Remove-InfisicalIdentityAuth.ps1
# Revokes the Universal Auth method from a machine identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalIdentityAuth {
    <#
    .SYNOPSIS
        Revokes the Universal Auth method from a machine identity.

    .DESCRIPTION
        Removes the Universal Auth configuration from the identity, revoking all
        client secrets and preventing authentication. Confirms by default.

    .PARAMETER IdentityId
        The ID of the machine identity.

    .EXAMPLE
        Remove-InfisicalIdentityAuth -IdentityId 'identity-123' -Confirm:$false

        Revokes Universal Auth without confirmation.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. All client secrets are immediately revoked.

    .LINK
        Add-InfisicalIdentityAuth
    .LINK
        Get-InfisicalIdentityAuth
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Revoking Universal Auth from identity '$IdentityId'")) {
        $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v1/auth/universal-auth/identities/$IdentityId" -Session $session

        if ($null -eq $response) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Universal Auth not configured for identity '$IdentityId'."),
                'InfisicalIdentityAuthNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $IdentityId
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
}
