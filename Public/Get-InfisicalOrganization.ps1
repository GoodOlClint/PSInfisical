# Get-InfisicalOrganization.ps1
# Retrieves organizations accessible to the current identity.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalOrganization {
    <#
    .SYNOPSIS
        Retrieves organizations from Infisical.

    .DESCRIPTION
        Retrieves the current identity's organization. When called without parameters,
        returns the organization associated with the current session (auto-resolved
        from the JWT during Connect-Infisical). When called with -Id, retrieves a
        specific organization by ID.

        Note: Machine identities belong to a single organization. The list behavior
        returns that organization.

    .PARAMETER Id
        The organization ID to retrieve. When specified, returns a single organization.

    .EXAMPLE
        Get-InfisicalOrganization

        Returns the organization for the current session.

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
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $session = Get-InfisicalSession

    $resolvedId = if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $Id
    }
    else {
        $session.OrganizationId
    }

    if ([string]::IsNullOrEmpty($resolvedId)) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new('OrganizationId is not available. Specify -Id or set it via Set-InfisicalSession -OrganizationId.'),
                'InfisicalOrganizationIdRequired',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $null
            )
        )
    }

    $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/organization/$resolvedId" -Session $session

    if ($null -eq $response -or $null -eq $response.organization) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Management.Automation.ItemNotFoundException]::new("Organization '$resolvedId' not found or access denied."),
            'InfisicalOrganizationNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $resolvedId
        )
        $PSCmdlet.WriteError($errorRecord)
        return
    }

    ConvertTo-InfisicalOrganizationObject -Data $response.organization
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
