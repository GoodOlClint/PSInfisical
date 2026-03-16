# Get-InfisicalIdentity.ps1
# Retrieves machine identities from an Infisical organization.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalIdentity class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalIdentity {
    <#
    .SYNOPSIS
        Retrieves machine identities from Infisical.

    .DESCRIPTION
        Lists machine identities in the specified organization, or retrieves a
        specific identity by ID. Machine identities are non-human accounts used
        for programmatic API access.

    .PARAMETER Id
        The identity ID to retrieve.

    .PARAMETER OrganizationId
        The organization ID to list identities from. Required for listing.

    .EXAMPLE
        Get-InfisicalIdentity -OrganizationId 'org-123'

        Returns all machine identities in the organization.

    .EXAMPLE
        Get-InfisicalIdentity -Id 'identity-abc-123'

        Returns a specific identity by ID.

    .OUTPUTS
        [InfisicalIdentity] or [InfisicalIdentity[]]

    .LINK
        New-InfisicalIdentity
    .LINK
        Remove-InfisicalIdentity
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([InfisicalIdentity], [InfisicalIdentity[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationId
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/identities/$Id" -Session $session

        if ($null -eq $response -or $null -eq $response.identity) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Identity '$Id' not found."),
                'InfisicalIdentityNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Id
            )
            $PSCmdlet.WriteError($errorRecord)
            return
        }

        return ConvertTo-InfisicalIdentity -IdentityData $response.identity
    }

    # List all identities in org
    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v1/identities' -QueryParameters @{ orgId = $OrganizationId } -Session $session

    if ($null -eq $response -or $null -eq $response.identities) {
        return
    }

    foreach ($identityData in $response.identities) {
        ConvertTo-InfisicalIdentity -IdentityData $identityData
    }
}
