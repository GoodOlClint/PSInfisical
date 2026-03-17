# Get-InfisicalOrganization.ps1
# Retrieves organizations accessible to the current identity/user.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalOrganization {
    <#
    .SYNOPSIS
        Retrieves organizations from Infisical.

    .DESCRIPTION
        Returns organizations accessible to the current session. Without parameters,
        lists all organizations the current user/identity has access to. With -Id,
        filters to a specific organization.

        User tokens (email/password login) can list all their organizations.
        Machine identity tokens may get a 403 on the list endpoint — use
        Set-InfisicalSession -OrganizationId instead.

    .PARAMETER Id
        The organization ID to retrieve. Filters the list to this specific org.

    .EXAMPLE
        Get-InfisicalOrganization

        Returns all organizations for the current session.

    .EXAMPLE
        Get-InfisicalOrganization -Id 'org-abc-123'

        Returns a specific organization by ID.

    .OUTPUTS
        PSCustomObject with Id, Name, Slug, and CreatedAt properties.

    .LINK
        Set-InfisicalSession
    .LINK
        Get-InfisicalProject
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSObject])]
    param(
        [Parameter(ParameterSetName = 'ById', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $session = Get-InfisicalSession

    # Use /api/v1/organization (singular) to list orgs — works for both user and
    # machine identity tokens (machine identities may get 403 depending on permissions).
    $response = Invoke-InfisicalApi -Method GET -Endpoint '/api/v1/organization' -Session $session

    if ($null -eq $response -or $null -eq $response.organizations) {
        return
    }

    $orgs = @($response.organizations)

    # Filter to specific ID if requested
    if (-not [string]::IsNullOrEmpty($Id)) {
        $orgs = @($orgs | Where-Object {
            $orgId = if ($_ -is [hashtable]) { $_['id'] } else { $_.id }
            $orgId -eq $Id
        })
        if ($orgs.Count -eq 0) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Management.Automation.ItemNotFoundException]::new("Organization '$Id' not found."),
                'InfisicalOrganizationNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $Id
            )
            $PSCmdlet.WriteError($errorRecord)
            return
        }
    }

    foreach ($org in $orgs) {
        ConvertTo-InfisicalOrganizationObject -Data $org
    }
}

function ConvertTo-InfisicalOrganizationObject {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [PSObject] $Data)

    $id = if ($Data -is [hashtable]) { $Data['id'] } else { $Data.id }
    $name = if ($Data -is [hashtable]) { $Data['name'] } else { $Data.name }
    $slug = if ($Data -is [hashtable] -and $Data.ContainsKey('slug')) { $Data['slug'] } elseif ($Data -isnot [hashtable] -and $Data.slug) { $Data.slug } else { '' }

    $createdAt = [datetime]::MinValue
    if ($Data.createdAt) { [void][datetime]::TryParse($Data.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }

    [PSCustomObject]@{
        PSTypeName = 'InfisicalOrganization'
        Id         = $id
        Name       = $name
        Slug       = $slug
        CreatedAt  = $createdAt
    }
}
