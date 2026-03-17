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

        [Parameter(ParameterSetName = 'List')]
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
    $resolvedOrgId = if ([string]::IsNullOrEmpty($OrganizationId)) { $session.OrganizationId } else { $OrganizationId }
    if ([string]::IsNullOrEmpty($resolvedOrgId)) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new('OrganizationId is required. Specify -OrganizationId or set it via Set-InfisicalSession.'),
                'InfisicalOrganizationIdRequired',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $null
            )
        )
    }
    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v1/identities' -QueryParameters @{ orgId = $resolvedOrgId } -Session $session

    if ($null -eq $response -or $null -eq $response.identities) {
        return
    }

    foreach ($membership in $response.identities) {
        # The list endpoint returns org membership wrappers with a nested .identity object.
        # Merge the nested identity data with membership-level fields (role, orgId, timestamps).
        $innerIdentity = if ($membership -is [hashtable]) { $membership['identity'] } else { $membership.identity }
        if ($null -ne $innerIdentity) {
            $merged = @{
                id                  = if ($innerIdentity -is [hashtable]) { $innerIdentity['id'] } else { $innerIdentity.id }
                name                = if ($innerIdentity -is [hashtable]) { $innerIdentity['name'] } else { $innerIdentity.name }
                orgId               = if ($membership -is [hashtable]) { $membership['orgId'] } else { $membership.orgId }
                role                = if ($membership -is [hashtable]) { $membership['role'] } else { $membership.role }
                authMethods         = if ($innerIdentity -is [hashtable]) { $innerIdentity['authMethods'] } else { $innerIdentity.authMethods }
                hasDeleteProtection = if ($innerIdentity -is [hashtable]) { $innerIdentity['hasDeleteProtection'] } else { $innerIdentity.hasDeleteProtection }
                createdAt           = if ($membership -is [hashtable]) { $membership['createdAt'] } else { $membership.createdAt }
                updatedAt           = if ($membership -is [hashtable]) { $membership['updatedAt'] } else { $membership.updatedAt }
            }
            ConvertTo-InfisicalIdentity -IdentityData ([PSCustomObject]$merged)
        }
        else {
            # Fallback: flat identity object (shouldn't happen for list, but be safe)
            ConvertTo-InfisicalIdentity -IdentityData $membership
        }
    }
}
