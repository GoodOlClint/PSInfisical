# Set-InfisicalSecretBulk.ps1
# Updates multiple secrets in a single API call.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecret class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalSecretBulk {
    <#
    .SYNOPSIS
        Updates multiple secrets in a single API call.

    .DESCRIPTION
        Batch updates secrets using the v4 bulk endpoint. Each secret is specified
        as a hashtable with at minimum Name and Value keys.

    .PARAMETER Secrets
        An array of hashtables, each with at minimum 'Name' and 'Value' keys.
        Optional keys: 'Comment', 'TagIds', 'NewName', 'SkipMultilineEncoding'.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the updated InfisicalSecret objects.

    .EXAMPLE
        $updates = @(
            @{ Name = 'DB_HOST'; Value = 'db.prod.internal' }
            @{ Name = 'DB_PORT'; Value = '5433' }
        )
        Set-InfisicalSecretBulk -Secrets $updates

        Updates two secrets in a single API call.

    .EXAMPLE
        Set-InfisicalSecretBulk -Secrets @(@{ Name = 'API_KEY'; Value = 'new-key'; NewName = 'SERVICE_KEY' }) -PassThru

        Renames a secret while updating its value and returns the result.

    .OUTPUTS
        [InfisicalSecret[]] when -PassThru is specified; otherwise, no output.

    .LINK
        Set-InfisicalSecret
    .LINK
        New-InfisicalSecretBulk
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

    if ($PSCmdlet.ShouldProcess("Updating $($Secrets.Count) secrets in path '$SecretPath' (environment: $resolvedEnvironment)")) {
        $secretArray = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($s in $Secrets) {
            $entry = @{
                secretKey = $s['Name']
            }
            $val = $s['Value']
            if ($val -is [System.Security.SecureString]) {
                $entry['secretValue'] = [System.Net.NetworkCredential]::new('', $val).Password
            } else {
                $entry['secretValue'] = [string]$val
            }
            if ($s.ContainsKey('Comment') -and $s['Comment'])     { $entry['secretComment'] = $s['Comment'] }
            if ($s.ContainsKey('TagIds') -and $s['TagIds'])       { $entry['tagIds'] = $s['TagIds'] }
            if ($s.ContainsKey('NewName') -and $s['NewName'])     { $entry['newSecretName'] = $s['NewName'] }
            if ($s.ContainsKey('SkipMultilineEncoding') -and $s['SkipMultilineEncoding']) { $entry['skipMultilineEncoding'] = $true }
            $secretArray.Add($entry)
        }

        $body = @{
            projectId   = $resolvedProjectId
            environment = $resolvedEnvironment
            secretPath  = $SecretPath
            secrets     = @($secretArray)
        }

        $response = Invoke-InfisicalApi -Method PATCH -Endpoint '/api/v4/secrets/bulk' -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.secrets) {
            foreach ($secretData in $response.secrets) {
                ConvertTo-InfisicalSecret -SecretData $secretData -Environment $resolvedEnvironment -ProjectId $resolvedProjectId -FallbackPath $SecretPath
            }
        }
    }
}
