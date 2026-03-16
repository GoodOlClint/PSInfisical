# New-InfisicalProjectRole.ps1
# Creates a custom role in an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalProjectRole {
    <#
    .SYNOPSIS
        Creates a custom role in an Infisical project.

    .DESCRIPTION
        Creates a project-level role with the specified permissions. Permissions
        define what actions the role can perform on which resources.

    .PARAMETER Name
        The display name for the role.

    .PARAMETER Slug
        The slug identifier for the role (1-64 characters).

    .PARAMETER Description
        An optional description of the role.

    .PARAMETER Permissions
        An array of permission hashtables. Each should contain 'subject', 'action',
        and optionally 'conditions'. See Infisical docs for permission schema.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the created role object.

    .EXAMPLE
        $perms = @(
            @{ subject = 'secrets'; action = @('read') }
        )
        New-InfisicalProjectRole -Name 'Read Only' -Slug 'read-only' -Permissions $perms

        Creates a role that can only read secrets.

    .EXAMPLE
        $perms = @(
            @{ subject = 'secrets'; action = @('read', 'create', 'edit', 'delete') }
            @{ subject = 'secret-folders'; action = @('read') }
        )
        New-InfisicalProjectRole -Name 'Secret Manager' -Slug 'secret-mgr' -Permissions $perms -PassThru

        Creates a role with full secret access and folder read access.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalProjectRole
    .LINK
        Remove-InfisicalProjectRole
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 64)]
        [string] $Slug,

        [Parameter()]
        [string] $Description,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable[]] $Permissions,

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Creating role '$Name' (slug: $Slug) in project '$resolvedProjectId'")) {
        $body = @{
            name        = $Name
            slug        = $Slug
            permissions = @($Permissions)
        }

        if (-not [string]::IsNullOrEmpty($Description)) {
            $body['description'] = $Description
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/projects/$resolvedProjectId/roles" -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.role) {
            return $response.role
        }
    }
}
