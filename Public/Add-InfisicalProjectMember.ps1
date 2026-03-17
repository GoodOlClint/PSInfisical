# Add-InfisicalProjectMember.ps1
# Grants a machine identity access to an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Add-InfisicalProjectMember {
    <#
    .SYNOPSIS
        Grants a machine identity access to an Infisical project.

    .DESCRIPTION
        Adds a machine identity as a member of the specified project with the given role.
        The identity must already exist in the organization.

    .PARAMETER IdentityId
        The ID of the machine identity to add.

    .PARAMETER Role
        The project role slug to assign (e.g., 'admin', 'member', 'viewer', or a custom role slug).

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Add-InfisicalProjectMember -IdentityId 'identity-123' -Role 'member'

        Grants the identity member access to the current project.

    .EXAMPLE
        Add-InfisicalProjectMember -IdentityId 'identity-123' -Role 'viewer' -ProjectId 'proj-456'

        Grants viewer access to a specific project.

    .PARAMETER PassThru
        Return the membership as a PSCustomObject.

    .OUTPUTS
        PSCustomObject (InfisicalProjectMembership) when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalProjectMember
    .LINK
        Remove-InfisicalProjectMember
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $IdentityId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Role,

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Granting identity '$IdentityId' role '$Role' on project '$resolvedProjectId'")) {
        $body = @{
            role = $Role
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v2/workspace/$resolvedProjectId/identity-memberships/$IdentityId" -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response) {
            $membership = if ($response -is [hashtable] -and $response.ContainsKey('identityMembership')) { $response['identityMembership'] } elseif ($response -isnot [hashtable] -and $response.PSObject.Properties['identityMembership']) { $response.identityMembership } else { $null }

            if ($null -eq $membership) { return $response }

            $id = if ($membership -is [hashtable] -and $membership.ContainsKey('id')) { $membership['id'] } elseif ($membership -isnot [hashtable] -and $membership.id) { $membership.id } else { '' }
            $projectIdOut = if ($membership -is [hashtable] -and $membership.ContainsKey('projectId')) { $membership['projectId'] } elseif ($membership -isnot [hashtable] -and $membership.PSObject.Properties['projectId']) { $membership.projectId } else { $resolvedProjectId }
            $identityIdOut = if ($membership -is [hashtable] -and $membership.ContainsKey('identityId')) { $membership['identityId'] } elseif ($membership -isnot [hashtable] -and $membership.PSObject.Properties['identityId']) { $membership.identityId } else { $IdentityId }
            $roleOut = if ($membership -is [hashtable] -and $membership.ContainsKey('role')) { $membership['role'] } elseif ($membership -isnot [hashtable] -and $membership.PSObject.Properties['role']) { $membership.role } else { $Role }

            $createdAt = [datetime]::MinValue
            $updatedAt = [datetime]::MinValue
            $rawCreated = if ($membership -is [hashtable] -and $membership.ContainsKey('createdAt')) { $membership['createdAt'] } elseif ($membership -isnot [hashtable] -and $membership.PSObject.Properties['createdAt']) { $membership.createdAt } else { $null }
            $rawUpdated = if ($membership -is [hashtable] -and $membership.ContainsKey('updatedAt')) { $membership['updatedAt'] } elseif ($membership -isnot [hashtable] -and $membership.PSObject.Properties['updatedAt']) { $membership.updatedAt } else { $null }
            if ($rawCreated) { [void][datetime]::TryParse($rawCreated, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }
            if ($rawUpdated) { [void][datetime]::TryParse($rawUpdated, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$updatedAt) }

            return [PSCustomObject]@{
                PSTypeName = 'InfisicalProjectMembership'
                Id         = $id
                ProjectId  = $projectIdOut
                IdentityId = $identityIdOut
                Role       = $roleOut
                CreatedAt  = $createdAt
                UpdatedAt  = $updatedAt
            }
        }
    }
}
