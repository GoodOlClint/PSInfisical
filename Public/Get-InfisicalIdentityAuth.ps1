# Get-InfisicalIdentityAuth.ps1
# Retrieves the Universal Auth configuration for a machine identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalIdentityAuth {
    <#
    .SYNOPSIS
        Retrieves the Universal Auth configuration for a machine identity.

    .DESCRIPTION
        Gets the authentication configuration including TTL settings, IP restrictions,
        and lockout policy for the specified identity.

    .PARAMETER IdentityId
        The ID of the machine identity.

    .EXAMPLE
        Get-InfisicalIdentityAuth -IdentityId 'identity-123'

        Returns the Universal Auth config for the identity.

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
        [string] $IdentityId
    )

    $session = Get-InfisicalSession

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/auth/universal-auth/identities/$IdentityId" -Session $session

    if ($null -eq $response) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Management.Automation.ItemNotFoundException]::new("Universal Auth not configured for identity '$IdentityId'."),
            'InfisicalIdentityAuthNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $IdentityId
        )
        $PSCmdlet.WriteError($errorRecord)
        return
    }

    return $response
}
