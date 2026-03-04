# New-InfisicalSecret.ps1
# Creates a new secret in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession, ConvertTo-InfisicalBody

function New-InfisicalSecret {
    <#
    .SYNOPSIS
        Creates a new secret in Infisical.

    .DESCRIPTION
        Creates a secret with the specified name and value in the Infisical secrets manager.
        Accepts SecureString values by default to prevent plaintext in memory. A secondary
        -PlainTextValue parameter is available for convenience but issues a warning.

    .PARAMETER Name
        The name (key) of the secret to create.

    .PARAMETER Value
        The secret value as a SecureString.

    .PARAMETER PlainTextValue
        The secret value as a plain string. Issues a warning because the plaintext
        string remains in managed memory. Prefer -Value with SecureString.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Comment
        An optional note or comment for the secret.

    .PARAMETER SkipMultilineEncoding
        Skip encoding for multiline secret values.

    .PARAMETER Force
        If the secret already exists, update it instead of failing. Enables
        idempotent create-or-update semantics for CI/CD scripts.

    .PARAMETER PassThru
        Return the created InfisicalSecret object.

    .EXAMPLE
        $value = Read-Host -AsSecureString -Prompt 'Secret value'
        New-InfisicalSecret -Name 'DATABASE_URL' -Value $value

        Creates a new secret with a SecureString value.

    .EXAMPLE
        New-InfisicalSecret 'API_KEY' -PlainTextValue 'sk-test-123' -PassThru

        Creates a secret with a plaintext value (with warning) and returns the created object.

    .EXAMPLE
        New-InfisicalSecret 'DATABASE_URL' -Value $secureValue -Force

        Creates the secret if it does not exist, or updates it if it already exists.

    .OUTPUTS
        [InfisicalSecret] when -PassThru is specified; otherwise, no output.

    .NOTES
        Use SecureString values whenever possible. The -PlainTextValue parameter
        is provided for convenience in non-interactive scenarios but the plaintext
        string will remain in managed memory until garbage collected.

    .LINK
        Set-InfisicalSecret
    .LINK
        Get-InfisicalSecret
    .LINK
        Remove-InfisicalSecret
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'SecureValue')]
    [OutputType([InfisicalSecret])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'SecureValue')]
        [ValidateNotNull()]
        [System.Security.SecureString] $Value,

        [Parameter(Mandatory, ParameterSetName = 'PlainTextValue')]
        [ValidateNotNullOrEmpty()]
        [string] $PlainTextValue,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [string] $Comment,

        [Parameter()]
        [switch] $SkipMultilineEncoding,

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    # Handle PlainTextValue — warn and convert to SecureString
    if ($PSCmdlet.ParameterSetName -eq 'PlainTextValue') {
        Write-Warning 'New-InfisicalSecret: Using -PlainTextValue. The plaintext string remains in managed memory. Prefer -Value with SecureString for better security.'
        $Value = [System.Security.SecureString]::new()
        foreach ($char in $PlainTextValue.ToCharArray()) {
            $Value.AppendChar($char)
        }
        $Value.MakeReadOnly()
    }

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }

    if ($PSCmdlet.ShouldProcess("Creating secret '$Name' in path '$SecretPath' (environment: $resolvedEnvironment)")) {
        $body = ConvertTo-InfisicalBody -Session $session -Environment $Environment -SecretPath $SecretPath -ProjectId $ProjectId -SecretValue $Value -Comment $Comment -SkipMultilineEncoding:$SkipMultilineEncoding

        $encodedName = [System.Uri]::EscapeDataString($Name)

        $response = $null
        $usedUpdate = $false
        try {
            $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v3/secrets/raw/$encodedName" -Body $body -Session $session
        }
        catch {
            if ($Force.IsPresent) {
                # Secret likely already exists — fall back to update
                Write-Verbose "New-InfisicalSecret: Create failed, updating existing secret '$Name' (-Force)."
                $setParams = @{
                    Name       = $Name
                    Value      = $Value
                    SecretPath = $SecretPath
                    Confirm    = $false
                }
                if (-not [string]::IsNullOrEmpty($Environment)) { $setParams['Environment'] = $Environment }
                if (-not [string]::IsNullOrEmpty($ProjectId))   { $setParams['ProjectId'] = $ProjectId }
                if (-not [string]::IsNullOrEmpty($Comment))     { $setParams['Comment'] = $Comment }
                if ($SkipMultilineEncoding.IsPresent)            { $setParams['SkipMultilineEncoding'] = $true }
                if ($PassThru.IsPresent)                         { $setParams['PassThru'] = $true }

                $result = Set-InfisicalSecret @setParams
                $usedUpdate = $true
                if ($PassThru.IsPresent) {
                    return $result
                }
                return
            }
            throw
        }

        if (-not $usedUpdate -and $PassThru.IsPresent -and $null -ne $response -and $null -ne $response.secret) {
            $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }
            return ConvertTo-InfisicalSecret -SecretData $response.secret -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
        }
    }
}
