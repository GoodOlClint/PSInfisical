# Remove-InfisicalIdentityAuth.ps1
# Revokes an authentication method from a machine identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalIdentityAuth {
    <#
    .SYNOPSIS
        Revokes an authentication method from a machine identity.

    .DESCRIPTION
        Removes the specified auth method configuration from the identity, revoking
        all associated credentials. Confirms by default.

    .PARAMETER IdentityId
        The ID of the machine identity.

    .PARAMETER AuthMethod
        The authentication method to revoke. Defaults to 'universal-auth'.

    .EXAMPLE
        Remove-InfisicalIdentityAuth -IdentityId 'identity-123' -Confirm:$false

        Revokes Universal Auth without confirmation.

    .EXAMPLE
        Remove-InfisicalIdentityAuth -IdentityId 'identity-123' -AuthMethod 'aws-auth'

        Revokes AWS Auth from the identity.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. All credentials for the auth method are
        immediately invalidated.

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
        [string] $IdentityId,

        [Parameter()]
        [ValidateSet('universal-auth', 'aws-auth', 'azure-auth', 'gcp-auth', 'kubernetes-auth', 'oidc-auth', 'jwt-auth', 'ldap-auth')]
        [string] $AuthMethod = 'universal-auth'
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Revoking '$AuthMethod' from identity '$IdentityId'")) {
        $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v1/auth/$AuthMethod/identities/$IdentityId" -Session $session

        if ($null -eq $response) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Auth method '$AuthMethod' not configured for identity '$IdentityId'."),
                'InfisicalIdentityAuthNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $IdentityId
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
}
