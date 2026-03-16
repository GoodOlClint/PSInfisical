# New-InfisicalSecretBulk.ps1
# Creates multiple secrets in a single API call.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalSecretBulk {
    <#
    .SYNOPSIS
        Creates multiple secrets in a single API call.

    .DESCRIPTION
        Batch creates secrets using the v4 bulk endpoint. Each secret is specified
        as a hashtable with at minimum Name and Value keys. More efficient than
        calling New-InfisicalSecret in a loop for CI/CD seeding scripts.

    .PARAMETER Secrets
        An array of hashtables, each with at minimum 'Name' and 'Value' keys.
        Optional keys: 'Comment', 'TagIds', 'SkipMultilineEncoding'.
        Value can be a string or SecureString.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the created InfisicalSecret objects.

    .EXAMPLE
        $secrets = @(
            @{ Name = 'DB_HOST'; Value = 'localhost' }
            @{ Name = 'DB_PORT'; Value = '5432' }
        )
        New-InfisicalSecretBulk -Secrets $secrets

        Creates two secrets in a single API call.

    .EXAMPLE
        @(@{ Name = 'KEY1'; Value = 'val1' }, @{ Name = 'KEY2'; Value = 'val2' }) |
            ForEach-Object { $_ } | New-InfisicalSecretBulk -PassThru

    .OUTPUTS
        [InfisicalSecret[]] when -PassThru is specified; otherwise, no output.

    .LINK
        New-InfisicalSecret
    .LINK
        Set-InfisicalSecretBulk
    .LINK
        Remove-InfisicalSecretBulk
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Bulk operation on multiple secrets')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalSecret[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [hashtable[]] $Secrets,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Creating $($Secrets.Count) secrets in path '$SecretPath' (environment: $resolvedEnvironment)")) {
        $secretArray = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($s in $Secrets) {
            $entry = @{
                secretKey = $s['Name']
            }
            # Handle SecureString or plain string value
            $val = $s['Value']
            if ($val -is [System.Security.SecureString]) {
                $entry['secretValue'] = [System.Net.NetworkCredential]::new('', $val).Password
            } else {
                $entry['secretValue'] = [string]$val
            }
            if ($s.ContainsKey('Comment') -and $s['Comment']) { $entry['secretComment'] = $s['Comment'] }
            if ($s.ContainsKey('TagIds') -and $s['TagIds'])   { $entry['tagIds'] = $s['TagIds'] }
            if ($s.ContainsKey('SkipMultilineEncoding') -and $s['SkipMultilineEncoding']) { $entry['skipMultilineEncoding'] = $true }
            $secretArray.Add($entry)
        }

        $body = @{
            projectId   = $resolvedProjectId
            environment = $resolvedEnvironment
            secretPath  = $SecretPath
            secrets     = @($secretArray)
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint '/api/v4/secrets/bulk' -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.secrets) {
            foreach ($secretData in $response.secrets) {
                ConvertTo-InfisicalSecret -SecretData $secretData -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
            }
        }
    }
}
