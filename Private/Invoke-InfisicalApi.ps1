# Invoke-InfisicalApi.ps1
# Core HTTP wrapper for all Infisical API calls. Handles authentication headers,
# error classification, rate-limit retries, and verbose logging.
# Called by: All public functions (via Get-InfisicalSession → caller → this function)
# Dependencies: InfisicalSession class

function Invoke-InfisicalApi {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string] $Method,

        [Parameter(Mandatory)]
        [string] $Endpoint,

        [Parameter()]
        [hashtable] $Body,

        [Parameter()]
        [hashtable] $QueryParameters,

        [Parameter(Mandatory)]
        [InfisicalSession] $Session
    )

    # Build full URI
    $baseUri = $Session.ApiUrl.TrimEnd('/')
    $uri = "$baseUri$Endpoint"

    # Append query parameters
    if ($QueryParameters -and $QueryParameters.Count -gt 0) {
        $queryParts = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $QueryParameters.Keys) {
            $encodedKey = [System.Uri]::EscapeDataString($key)
            $encodedValue = [System.Uri]::EscapeDataString([string]$QueryParameters[$key])
            $queryParts.Add("$encodedKey=$encodedValue")
        }
        $uri = "$uri`?$($queryParts -join '&')"
    }

    # Build headers — never log the token value
    $tokenPlainText = $Session.GetAccessTokenPlainText()
    $headers = @{
        'Authorization' = "Bearer $tokenPlainText"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }

    # Build invoke parameters
    $invokeParams = @{
        Uri         = $uri
        Method      = $Method
        Headers     = $headers
        TimeoutSec  = 30
        ErrorAction = 'Stop'
    }

    if ($Method -in @('POST', 'PATCH', 'DELETE')) {
        if ($Body -and $Body.Count -gt 0) {
            $invokeParams['Body'] = ($Body | ConvertTo-Json -Depth 10 -Compress)
        }
        else {
            # Some endpoints require a JSON body even when empty
            $invokeParams['Body'] = '{}'
        }
        $invokeParams['ContentType'] = 'application/json'
    }

    # Check API version compatibility before making the call
    Assert-InfisicalApiVersion -Endpoint $Endpoint -Session $Session

    # Verbose logging — endpoint and method only, never secrets or tokens
    Write-Verbose "Invoke-InfisicalApi: $Method $Endpoint"

    # Retry logic for 429 (rate limit) with exponential backoff
    $maxRetries = 3
    $attempt = 0

    while ($true) {
        $attempt++
        try {
            $response = Invoke-RestMethod @invokeParams
            Write-Verbose "Invoke-InfisicalApi: Response received successfully"
            return $response
        }
        catch {
            $statusCode = $null
            $responseBody = $null

            # Extract error details defensively — $_ may be an ErrorRecord
            # or a raw exception depending on how the error was thrown.
            $caughtException = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.Exception
            }
            else {
                $_
            }
            $caughtErrorDetails = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.ErrorDetails
            }
            else {
                $null
            }

            if ($caughtException -is [System.Net.WebException] -and $null -ne $caughtException.Response) {
                # Windows PowerShell 5.1 path
                $webResponse = $caughtException.Response
                $statusCode = [int]$webResponse.StatusCode
                try {
                    $stream = $webResponse.GetResponseStream()
                    if ($null -ne $stream) {
                        $reader = [System.IO.StreamReader]::new($stream)
                        $responseBody = $reader.ReadToEnd()
                        $reader.Dispose()
                    }
                }
                finally {
                    $webResponse.Dispose()
                }
            }
            elseif ($null -ne $caughtException -and $caughtException.GetType().Name -eq 'HttpResponseException') {
                # PowerShell 7+ path — use name check to avoid type load failures on PS 5.1
                $statusCode = [int]$caughtException.Response.StatusCode
                if ($null -ne $caughtErrorDetails) {
                    $responseBody = $caughtErrorDetails.Message
                }
            }
            elseif ($null -ne $caughtErrorDetails -and $caughtErrorDetails.Message) {
                $responseBody = $caughtErrorDetails.Message
                # Try to extract status code from the exception's Response property
                if ($null -ne $caughtException -and $null -ne $caughtException.PSObject.Properties['Response'] -and $null -ne $caughtException.Response) {
                    $statusCode = [int]$caughtException.Response.StatusCode
                }
            }

            Write-Verbose "Invoke-InfisicalApi: Error response — Status: $statusCode"

            switch ($statusCode) {
                401 {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.UnauthorizedAccessException]::new(
                            'Authentication failed or token expired. Run Connect-Infisical to re-authenticate.'
                        ),
                        'InfisicalAuthenticationFailed',
                        [System.Management.Automation.ErrorCategory]::AuthenticationError,
                        $Endpoint
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                403 {
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.UnauthorizedAccessException]::new(
                            'Access denied. Check machine identity permissions for this resource.'
                        ),
                        'InfisicalAccessDenied',
                        [System.Management.Automation.ErrorCategory]::PermissionDenied,
                        $Endpoint
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                404 {
                    return $null
                }
                429 {
                    if ($attempt -lt $maxRetries) {
                        $backoffSeconds = [math]::Pow(2, $attempt)
                        Write-Verbose "Invoke-InfisicalApi: Rate limited (429). Retrying in $backoffSeconds seconds (attempt $attempt of $maxRetries)."
                        Start-Sleep -Seconds $backoffSeconds
                        continue
                    }
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.InvalidOperationException]::new(
                            "Rate limit exceeded after $maxRetries retry attempts. Try again later."
                        ),
                        'InfisicalRateLimitExceeded',
                        [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                        $Endpoint
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                { $_ -ge 500 } {
                    # Parse response body for message, but never include raw body
                    # that might contain secrets
                    $errorMsg = "Infisical API returned server error (HTTP $statusCode)."
                    if ($responseBody) {
                        try {
                            $parsed = $responseBody | ConvertFrom-Json
                            if ($parsed.message) {
                                $errorMsg = "Infisical API error (HTTP $statusCode): $($parsed.message)"
                            }
                        }
                        catch {
                            # Could not parse JSON; use generic message
                            $null = $_
                        }
                    }
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.InvalidOperationException]::new($errorMsg),
                        'InfisicalServerError',
                        [System.Management.Automation.ErrorCategory]::ConnectionError,
                        $Endpoint
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
                default {
                    # Network or unknown errors
                    if ($null -eq $statusCode) {
                        $exceptionMsg = if ($null -ne $caughtException) { $caughtException.Message } else { 'Unknown error' }
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            [System.Net.WebException]::new(
                                "Unable to connect to Infisical API at $($Session.ApiUrl). Check your ApiUrl and network connectivity. Details: $exceptionMsg"
                            ),
                            'InfisicalConnectionError',
                            [System.Management.Automation.ErrorCategory]::ConnectionError,
                            $uri
                        )
                        $PSCmdlet.ThrowTerminatingError($errorRecord)
                    }
                    # Unhandled status codes (e.g. 409 Conflict) — try to surface API message
                    $errorMsg = "Infisical API returned HTTP $statusCode."
                    if ($responseBody) {
                        try {
                            $parsed = $responseBody | ConvertFrom-Json
                            if ($parsed.message) {
                                $errorMsg = "Infisical API error (HTTP $statusCode): $($parsed.message)"
                            }
                        }
                        catch {
                            # Could not parse JSON; use generic message
                            $null = $_
                        }
                    }
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.InvalidOperationException]::new($errorMsg),
                        'InfisicalApiError',
                        [System.Management.Automation.ErrorCategory]::InvalidResult,
                        $Endpoint
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }
            }
        }
    }
}
