# Remove-InfisicalSecretImport.ps1
# Deletes a secret import from Infisical.
# Called by: User directly. Supports pipeline input.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalSecretImport {
    <#
    .SYNOPSIS
        Removes a secret import from Infisical.

    .DESCRIPTION
        Deletes the specified secret import. Confirms by default.

    .PARAMETER Id
        The ID of the secret import to remove. Accepts pipeline input by property name.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The path context. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Remove-InfisicalSecretImport -Id 'import-001' -Confirm:$false

        Removes a secret import without confirmation.

    .EXAMPLE
        Get-InfisicalSecretImport | Remove-InfisicalSecretImport

        Removes all secret imports at the current path.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. Use -WhatIf to preview.

    .LINK
        Get-InfisicalSecretImport
    .LINK
        New-InfisicalSecretImport
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId
    )

    process {
        $session = Get-InfisicalSession

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }
        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Removing secret import '$Id'")) {
            $body = @{
                projectId   = $resolvedProjectId
                environment = $resolvedEnvironment
                path        = $SecretPath
            }

            $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v2/secret-imports/$Id" -Body $body -Session $session

            if ($null -eq $response) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new("Secret import '$Id' not found."),
                    'InfisicalSecretImportNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Id
                )
                $PSCmdlet.WriteError($errorRecord)
            }
        }
    }
}
