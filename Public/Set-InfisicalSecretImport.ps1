# Set-InfisicalSecretImport.ps1
# Updates an existing secret import in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalSecretImport class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalSecretImport {
    <#
    .SYNOPSIS
        Updates an existing secret import in Infisical.

    .DESCRIPTION
        Updates the source, position, or replication settings of an existing secret import.

    .PARAMETER Id
        The ID of the secret import to update. Accepts pipeline input by property name.

    .PARAMETER SourceEnvironment
        The new source environment slug.

    .PARAMETER SourcePath
        The new source path.

    .PARAMETER Environment
        The environment slug for context. Overrides the session default if specified.

    .PARAMETER SecretPath
        The destination path for context. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Position
        The import priority position (lower = higher priority).

    .PARAMETER IsReplication
        Enable or disable automatic replication.

    .PARAMETER PassThru
        Return the updated InfisicalSecretImport object.

    .EXAMPLE
        Set-InfisicalSecretImport -Id 'import-001' -Position 1

        Moves an import to the highest priority position.

    .OUTPUTS
        [InfisicalSecretImport] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalSecretImport
    .LINK
        New-InfisicalSecretImport
    .LINK
        Remove-InfisicalSecretImport
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalSecretImport])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [string] $SourceEnvironment,

        [Parameter()]
        [string] $SourcePath,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId,

        [Parameter()]
        [int] $Position,

        [Parameter()]
        [switch] $IsReplication,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        $session = Get-InfisicalSession

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Updating secret import '$Id'")) {
            $body = @{
                projectId   = $resolvedProjectId
                environment = $resolvedEnvironment
                path        = $SecretPath
            }

            if (-not [string]::IsNullOrEmpty($SourceEnvironment) -or -not [string]::IsNullOrEmpty($SourcePath)) {
                $importObj = @{}
                if (-not [string]::IsNullOrEmpty($SourceEnvironment)) { $importObj['environment'] = $SourceEnvironment }
                if (-not [string]::IsNullOrEmpty($SourcePath))        { $importObj['path'] = $SourcePath }
                $body['import'] = $importObj
            }

            if ($PSBoundParameters.ContainsKey('Position')) {
                $body['position'] = $Position
            }

            if ($PSBoundParameters.ContainsKey('IsReplication')) {
                $body['isReplication'] = $IsReplication.IsPresent
            }

            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v2/secret-imports/$Id" -Body $body -Session $session

            if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.secretImport) {
                return ConvertTo-InfisicalSecretImport -ImportData $response.secretImport -ProjectId $resolvedProjectId -Environment $resolvedEnvironment -Path $SecretPath
            }
        }
    }
}
