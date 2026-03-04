# Set-InfisicalSecret.ps1
# Updates an existing secret in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession, ConvertTo-InfisicalBody

function Set-InfisicalSecret {
    <#
    .SYNOPSIS
        Updates an existing secret in Infisical.

    .DESCRIPTION
        Updates the value and/or comment of an existing secret in Infisical.
        Accepts SecureString values by default to prevent plaintext in memory.
        A secondary -PlainTextValue parameter is available for convenience.

    .PARAMETER Name
        The name (key) of the secret to update.

    .PARAMETER Value
        The new secret value as a SecureString.

    .PARAMETER PlainTextValue
        The new secret value as a plain string. Issues a warning because the
        plaintext string remains in managed memory.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Comment
        An optional note or comment to set on the secret.

    .PARAMETER SkipMultilineEncoding
        Skip encoding for multiline secret values.

    .PARAMETER PassThru
        Return the updated InfisicalSecret object.

    .EXAMPLE
        $newValue = Read-Host -AsSecureString -Prompt 'New value'
        Set-InfisicalSecret -Name 'DATABASE_URL' -Value $newValue

        Updates the DATABASE_URL secret with a new SecureString value.

    .EXAMPLE
        Set-InfisicalSecret 'API_KEY' -PlainTextValue 'sk-new-key' -PassThru

        Updates the secret and returns the updated object.

    .OUTPUTS
        [InfisicalSecret] when -PassThru is specified; otherwise, no output.

    .NOTES
        Use SecureString values whenever possible. The -PlainTextValue parameter
        is provided for convenience but the plaintext string will remain in
        managed memory until garbage collected.

    .LINK
        Get-InfisicalSecret
    .LINK
        New-InfisicalSecret
    .LINK
        Remove-InfisicalSecret
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'SecureValue')]
    [OutputType([InfisicalSecret])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'SecureValue')]
        [ValidateNotNull()]
        [System.Security.SecureString] $Value,

        [Parameter(Mandatory, ParameterSetName = 'PlainTextValue')]
        [ValidateNotNullOrEmpty()]
        [string] $PlainTextValue,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId,

        [Parameter()]
        [string] $Comment,

        [Parameter()]
        [switch] $SkipMultilineEncoding,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        $session = Get-InfisicalSession

        # Handle PlainTextValue — warn and convert to SecureString
        if ($PSCmdlet.ParameterSetName -eq 'PlainTextValue') {
            Write-Warning 'Set-InfisicalSecret: Using -PlainTextValue. The plaintext string remains in managed memory. Prefer -Value with SecureString for better security.'
            $Value = [System.Security.SecureString]::new()
            foreach ($char in $PlainTextValue.ToCharArray()) {
                $Value.AppendChar($char)
            }
            $Value.MakeReadOnly()
        }

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }

        if ($PSCmdlet.ShouldProcess("Updating secret '$Name' in path '$SecretPath' (environment: $resolvedEnvironment)")) {
            $body = ConvertTo-InfisicalBody -Session $session -Environment $Environment -SecretPath $SecretPath -ProjectId $ProjectId -SecretValue $Value -Comment $Comment -SkipMultilineEncoding:$SkipMultilineEncoding

            $encodedName = [System.Uri]::EscapeDataString($Name)
            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v3/secrets/raw/$encodedName" -Body $body -Session $session

            if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.secret) {
                $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }
                return ConvertTo-InfisicalSecret -SecretData $response.secret -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
            }
        }
    }
}
