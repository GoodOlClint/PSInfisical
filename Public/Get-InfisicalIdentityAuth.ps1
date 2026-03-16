# Get-InfisicalIdentityAuth.ps1
# Retrieves the auth configuration for a machine identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalIdentityAuth {
    <#
    .SYNOPSIS
        Retrieves the auth configuration for a machine identity.

    .DESCRIPTION
        Gets the authentication configuration including TTL settings, IP restrictions,
        and method-specific settings for the specified identity and auth method.

    .PARAMETER IdentityId
        The ID of the machine identity.

    .PARAMETER AuthMethod
        The authentication method to retrieve. Defaults to 'universal-auth'.

    .EXAMPLE
        Get-InfisicalIdentityAuth -IdentityId 'identity-123'

        Returns the Universal Auth config for the identity.

    .EXAMPLE
        Get-InfisicalIdentityAuth -IdentityId 'identity-123' -AuthMethod 'kubernetes-auth'

        Returns the Kubernetes Auth config.

    .OUTPUTS
        PSCustomObject with auth configuration properties.

    .LINK
        Add-InfisicalIdentityAuth
    .LINK
        Remove-InfisicalIdentityAuth
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter()]
        [ValidateSet('universal-auth', 'aws-auth', 'azure-auth', 'gcp-auth', 'kubernetes-auth', 'oidc-auth', 'jwt-auth', 'ldap-auth')]
        [string] $AuthMethod = 'universal-auth'
    )

    $session = Get-InfisicalSession

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/auth/$AuthMethod/identities/$IdentityId" -Session $session

    if ($null -eq $response) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Management.Automation.ItemNotFoundException]::new("Auth method '$AuthMethod' not configured for identity '$IdentityId'."),
            'InfisicalIdentityAuthNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $IdentityId
        )
        $PSCmdlet.WriteError($errorRecord)
        return
    }

    return $response
}
