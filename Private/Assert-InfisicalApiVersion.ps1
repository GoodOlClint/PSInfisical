# Assert-InfisicalApiVersion.ps1
# Checks that the connected Infisical server supports the required API version.
# Throws a terminating error with clear guidance if the endpoint is unsupported.
# Called by: Invoke-InfisicalApi when a version-specific endpoint is used.
# Dependencies: InfisicalSession class

function Assert-InfisicalApiVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Endpoint,

        [Parameter(Mandatory)]
        [InfisicalSession] $Session
    )

    # Only check if capabilities have been probed (populated during Connect-Infisical)
    if ($null -eq $Session.ApiCapabilities -or $Session.ApiCapabilities.Count -eq 0) {
        return
    }

    # Map endpoint version prefixes to capability keys
    if ($Endpoint -match '^/api/v4/secrets') {
        if (-not $Session.ApiCapabilities['SecretsV4']) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.NotSupportedException]::new(
                    "Your Infisical server does not support API v4 secret endpoints (required by this version of PSInfisical). " +
                    "Upgrade your Infisical instance, or use PSInfisical v0.1.x which uses the v3 API."
                ),
                'InfisicalApiVersionUnsupported',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $Endpoint
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
    elseif ($Endpoint -match '^/api/v3/secrets') {
        if (-not $Session.ApiCapabilities['SecretsV3']) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.NotSupportedException]::new(
                    "Your Infisical server does not support API v3 secret endpoints. " +
                    "This indicates a very old Infisical version. Please upgrade your Infisical instance."
                ),
                'InfisicalApiVersionUnsupported',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $Endpoint
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}
