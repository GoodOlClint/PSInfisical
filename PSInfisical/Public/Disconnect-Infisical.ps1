# Disconnect-Infisical.ps1
# Clears the module-scoped Infisical session, ending the authenticated connection.
# Called by: User directly, when finished with Infisical operations.
# Dependencies: InfisicalSession class

function Disconnect-Infisical {
    <#
    .SYNOPSIS
        Disconnects from the Infisical API and clears the session.

    .DESCRIPTION
        Clears the module-scoped Infisical session, removing stored credentials
        and access tokens from memory. Supports -WhatIf and -Confirm for safety.
        After disconnecting, all secret commands will require a new Connect-Infisical call.

    .EXAMPLE
        Disconnect-Infisical

        Clears the current Infisical session.

    .EXAMPLE
        Disconnect-Infisical -Verbose

        Clears the session with verbose output confirming the disconnection.

    .OUTPUTS
        None

    .NOTES
        This does not revoke tokens on the server side. The access token simply
        becomes unavailable locally. For UniversalAuth, the token will expire
        according to its server-configured TTL.

    .LINK
        Connect-Infisical
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([void])]
    param()

    if ($PSCmdlet.ShouldProcess('Infisical session', 'Disconnect')) {
        if ($null -ne $script:InfisicalSession) {
            Write-Verbose "Disconnect-Infisical: Clearing session for $($script:InfisicalSession.ApiUrl)"
            # Dispose SecureStrings to immediately zero their unmanaged buffers
            if ($null -ne $script:InfisicalSession.AccessToken) {
                $script:InfisicalSession.AccessToken.Dispose()
            }
            if ($null -ne $script:InfisicalSession.ClientSecret) {
                $script:InfisicalSession.ClientSecret.Dispose()
            }
        }
        else {
            Write-Verbose 'Disconnect-Infisical: No active session to clear.'
        }

        $script:InfisicalSession = $null
        Write-Verbose 'Disconnect-Infisical: Session cleared.'
    }
}
