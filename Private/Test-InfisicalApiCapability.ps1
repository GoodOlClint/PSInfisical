# Test-InfisicalApiCapability.ps1
# Probes the Infisical server to detect which API versions are available.
# Called by: Connect-Infisical after successful authentication.
# Dependencies: InfisicalSession class

function Test-InfisicalApiCapability {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [InfisicalSession] $Session
    )

    $capabilities = @{
        SecretsV4 = $false
        SecretsV3 = $false
    }

    $tokenPlainText = $Session.GetAccessTokenPlainText()
    $headers = @{
        'Authorization' = "Bearer $tokenPlainText"
        'Accept'        = 'application/json'
    }
    $baseUri = $Session.ApiUrl.TrimEnd('/')

    # Probe each version with its correct endpoint path and parameter name.
    # v4 uses /api/v4/secrets with projectId; v3 uses /api/v3/secrets/raw with workspaceId.
    $probes = @(
        @{ Version = 'v4'; Path = '/api/v4/secrets'; ParamName = 'projectId'; Key = 'SecretsV4' }
        @{ Version = 'v3'; Path = '/api/v3/secrets/raw'; ParamName = 'workspaceId'; Key = 'SecretsV3' }
    )

    foreach ($probe in $probes) {
        # Skip probe if no ProjectId is set (can't probe without it)
        if ([string]::IsNullOrEmpty($Session.ProjectId)) { continue }

        $probeUri = "$baseUri$($probe.Path)"
        try {
            # Use the list endpoint with required params -- even if the query fails with a
            # permission/validation error, a non-404 response means the route exists.
            $null = Invoke-RestMethod -Uri "$probeUri`?$($probe.ParamName)=$($Session.ProjectId)&environment=$($Session.DefaultEnvironment)&secretPath=/" `
                -Method GET -Headers $headers -TimeoutSec 10 -ErrorAction Stop
            $capabilities[$probe.Key] = $true
        }
        catch {
            $statusCode = $null
            $caughtException = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception } else { $_ }

            if ($caughtException -is [System.Net.WebException] -and $null -ne $caughtException.Response) {
                $statusCode = [int]$caughtException.Response.StatusCode
                $caughtException.Response.Dispose()
            }
            elseif ($null -ne $caughtException -and $caughtException.GetType().Name -eq 'HttpResponseException') {
                $statusCode = [int]$caughtException.Response.StatusCode
            }

            # Any response other than 404 means the route exists (could be 400, 401, 403, etc.)
            if ($null -ne $statusCode -and $statusCode -ne 404) {
                $capabilities[$probe.Key] = $true
            }
        }
    }

    Write-Verbose "Test-InfisicalApiCapability: SecretsV4=$($capabilities.SecretsV4), SecretsV3=$($capabilities.SecretsV3)"
    return $capabilities
}
