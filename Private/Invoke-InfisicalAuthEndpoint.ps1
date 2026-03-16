# Invoke-InfisicalAuthEndpoint.ps1
# Calls an Infisical authentication endpoint and returns the response.
# Shared helper for all auth methods in Connect-Infisical.
# Called by: Connect-Infisical
# Dependencies: None (uses Invoke-RestMethod directly)

function Invoke-InfisicalAuthEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ApiUrl,

        [Parameter(Mandatory)]
        [string] $AuthPath,

        [Parameter(Mandatory)]
        [hashtable] $Body,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $CallerCmdlet
    )

    $authUri = "$ApiUrl/api/v1/auth/$AuthPath/login"
    $bodyJson = $Body | ConvertTo-Json -Compress

    Write-Verbose "Invoke-InfisicalAuthEndpoint: POST $authUri"

    try {
        $response = Invoke-RestMethod -Uri $authUri -Method POST -Body $bodyJson -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop
    }
    catch {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Security.Authentication.AuthenticationException]::new(
                "$AuthPath login failed: $($_.Exception.Message)"
            ),
            "InfisicalAuthFailed_$AuthPath",
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $authUri
        )
        $CallerCmdlet.ThrowTerminatingError($errorRecord)
    }

    if (-not $response -or [string]::IsNullOrEmpty($response.accessToken)) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Security.Authentication.AuthenticationException]::new(
                "$AuthPath login succeeded but the response did not contain an access token."
            ),
            "InfisicalAuthNoToken_$AuthPath",
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $authUri
        )
        $CallerCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $response
}
