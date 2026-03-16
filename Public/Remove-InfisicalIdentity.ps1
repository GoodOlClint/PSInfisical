# Remove-InfisicalIdentity.ps1
# Deletes a machine identity from Infisical.
# Called by: User directly. Supports pipeline input.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Remove-InfisicalIdentity {
    <#
    .SYNOPSIS
        Removes a machine identity from Infisical.

    .DESCRIPTION
        Deletes the specified machine identity. This revokes all credentials and
        removes all project memberships. Confirms by default.

    .PARAMETER Id
        The ID of the identity to remove. Accepts pipeline input by property name.

    .EXAMPLE
        Remove-InfisicalIdentity -Id 'identity-abc-123' -Confirm:$false

        Removes an identity without confirmation.

    .EXAMPLE
        Get-InfisicalIdentity -OrganizationId 'org-123' |
            Where-Object Name -like 'temp-*' | Remove-InfisicalIdentity

        Removes identities matching a pattern via pipeline.

    .OUTPUTS
        None

    .NOTES
        This is a destructive operation. All credentials and project memberships
        are permanently revoked. Use -WhatIf to preview.

    .LINK
        Get-InfisicalIdentity
    .LINK
        New-InfisicalIdentity
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    process {
        $session = Get-InfisicalSession

        if ($PSCmdlet.ShouldProcess("Removing identity '$Id'")) {
            $response = Invoke-InfisicalApi -Method DELETE -Endpoint "/api/v1/identities/$Id" -Session $session

            if ($null -eq $response) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new("Identity '$Id' not found."),
                    'InfisicalIdentityNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Id
                )
                $PSCmdlet.WriteError($errorRecord)
            }
        }
    }
}
