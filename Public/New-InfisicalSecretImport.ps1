# New-InfisicalSecretImport.ps1
# Creates a new secret import in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecretImport class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalSecretImport {
    <#
    .SYNOPSIS
        Creates a new secret import in Infisical.

    .DESCRIPTION
        Creates a secret import that copies or replicates secrets from a source
        environment/path to a destination environment/path.

    .PARAMETER SourceEnvironment
        The environment slug to import secrets from.

    .PARAMETER SourcePath
        The path to import secrets from.

    .PARAMETER Environment
        The destination environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The destination path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER IsReplication
        Enable automatic replication of secrets from source to destination.

    .PARAMETER PassThru
        Return the created InfisicalSecretImport object.

    .EXAMPLE
        New-InfisicalSecretImport -SourceEnvironment 'prod' -SourcePath '/shared'

        Imports secrets from prod:/shared into the current environment and path.

    .EXAMPLE
        New-InfisicalSecretImport -SourceEnvironment 'staging' -SourcePath '/' -IsReplication -PassThru

        Creates a replicated import and returns the created object.

    .OUTPUTS
        [InfisicalSecretImport] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalSecretImport
    .LINK
        Remove-InfisicalSecretImport
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalSecretImport])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourceEnvironment,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $IsReplication,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Creating secret import from '$($SourceEnvironment):$SourcePath' to '$($resolvedEnvironment):$SecretPath'")) {
        $body = @{
            projectId   = $resolvedProjectId
            environment = $resolvedEnvironment
            path        = $SecretPath
            import      = @{
                environment = $SourceEnvironment
                path        = $SourcePath
            }
        }

        if ($IsReplication.IsPresent) {
            $body['isReplication'] = $true
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint '/api/v2/secret-imports' -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.secretImport) {
            return ConvertTo-InfisicalSecretImport -ImportData $response.secretImport -ProjectId $resolvedProjectId -Environment $resolvedEnvironment -Path $SecretPath
        }
    }
}
