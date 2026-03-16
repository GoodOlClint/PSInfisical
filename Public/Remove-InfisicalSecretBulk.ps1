# Remove-InfisicalSecretBulk.ps1
# Deletes multiple secrets in a single API call.
# Called by: User directly. Supports pipeline input from Get-InfisicalSecrets.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalSecretBulk {
    <#
    .SYNOPSIS
        Removes multiple secrets in a single API call.

    .DESCRIPTION
        Batch deletes secrets using the v4 bulk endpoint. Accepts an array of names
        or pipeline input (accumulates names in begin/process/end pattern).

    .PARAMETER Names
        An array of secret names to delete.

    .PARAMETER Name
        A single secret name, for pipeline input. Accumulated and sent as a batch in end block.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Remove-InfisicalSecretBulk -Names @('TEMP_KEY1', 'TEMP_KEY2') -Confirm:$false

        Deletes two secrets in a single API call.

    .EXAMPLE
        Get-InfisicalSecrets -Filter { $_.Name -like 'TEMP_*' } | Remove-InfisicalSecretBulk

        Deletes all secrets matching the filter via pipeline.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. Use -WhatIf to preview.

    .LINK
        Remove-InfisicalSecret
    .LINK
        New-InfisicalSecretBulk
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Bulk operation on multiple secrets')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByArray')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'ByArray')]
        [ValidateNotNull()]
        [string[]] $Names,

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ByPipeline')]
        [string] $Name,

        [Parameter()]
        [string] $Environment,

        [Parameter()]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter()]
        [string] $ProjectId
    )

    begin {
        $pipelineNames = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByPipeline' -and -not [string]::IsNullOrEmpty($Name)) {
            $pipelineNames.Add($Name)
        }
    }

    end {
        $namesToDelete = @(if ($PSCmdlet.ParameterSetName -eq 'ByArray') { $Names } else { $pipelineNames.ToArray() })

        if ($namesToDelete.Count -eq 0) { return }

        $session = Get-InfisicalSession

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Removing $($namesToDelete.Count) secrets from path '$SecretPath' (environment: $resolvedEnvironment)")) {
            $secretArray = @($namesToDelete | ForEach-Object { @{ secretKey = $_ } })

            $body = @{
                projectId   = $resolvedProjectId
                environment = $resolvedEnvironment
                secretPath  = $SecretPath
                secrets     = $secretArray
            }

            Invoke-InfisicalApi -Method DELETE -Endpoint '/api/v4/secrets/bulk' -Body $body -Session $session | Out-Null
        }
    }
}
