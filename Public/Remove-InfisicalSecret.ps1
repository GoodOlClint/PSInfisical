# Remove-InfisicalSecret.ps1
# Deletes a secret from Infisical.
# Called by: User directly. Supports pipeline input from Get-InfisicalSecrets.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession, ConvertTo-InfisicalBody

function Remove-InfisicalSecret {
    <#
    .SYNOPSIS
        Removes a secret from Infisical.

    .DESCRIPTION
        Deletes the specified secret from the Infisical secrets manager. Supports
        pipeline input from Get-InfisicalSecrets for bulk cleanup scenarios.
        Confirms by default due to the destructive nature of the operation.

    .PARAMETER Name
        The name (key) of the secret to remove. Accepts pipeline input by property name.

    .PARAMETER Environment
        The environment slug. Overrides the session default if specified.

    .PARAMETER SecretPath
        The Infisical folder path. Defaults to "/".

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER Type
        The secret type to delete: 'shared' (default) or 'personal'.

    .EXAMPLE
        Remove-InfisicalSecret -Name 'OLD_API_KEY' -Confirm:$false

        Removes a secret without confirmation.

    .EXAMPLE
        Get-InfisicalSecrets -Filter { $_.Name -like 'TEMP_*' } | Remove-InfisicalSecret

        Removes all secrets with names starting with TEMP_, with confirmation for each.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. The secret and all its versions are permanently
        deleted. Use -WhatIf to preview which secrets would be removed.

    .LINK
        Get-InfisicalSecrets
    .LINK
        Get-InfisicalSecret
    .LINK
        New-InfisicalSecret
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Environment,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string] $SecretPath = '/',

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId,

        [Parameter()]
        [ValidateSet('shared', 'personal')]
        [string] $Type
    )

    process {
        $session = Get-InfisicalSession

        $resolvedEnvironment = if ([string]::IsNullOrEmpty($Environment)) { $session.DefaultEnvironment } else { $Environment }

        if ($PSCmdlet.ShouldProcess("Removing secret '$Name' from path '$SecretPath' (environment: $resolvedEnvironment)")) {
            $bodyParams = @{
                Session     = $session
                Environment = $Environment
                SecretPath  = $SecretPath
                ProjectId   = $ProjectId
            }
            if (-not [string]::IsNullOrEmpty($Type)) { $bodyParams['Type'] = $Type }
            $body = ConvertTo-InfisicalBody @bodyParams

            $encodedName = [System.Uri]::EscapeDataString($Name)
            $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v4/secrets/$encodedName" -Body $body -Session $session

            if ($null -eq $response) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new(
                        "Secret '$Name' not found in environment '$resolvedEnvironment' at path '$SecretPath'."
                    ),
                    'InfisicalSecretNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Name
                )
                $PSCmdlet.WriteError($errorRecord)
            }
        }
    }
}
