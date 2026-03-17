# New-InfisicalProject.ps1
# Creates a new project/workspace in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalProject {
    <#
    .SYNOPSIS
        Creates a new project in Infisical.

    .DESCRIPTION
        Creates a new project/workspace in the specified organization.

    .PARAMETER Name
        The name of the project to create.

    .PARAMETER OrganizationId
        The organization ID to create the project in.

    .PARAMETER PassThru
        Return the created project object.

    .EXAMPLE
        New-InfisicalProject -Name 'my-app' -OrganizationId 'org-123' -PassThru

        Creates a project and returns it.

    .EXAMPLE
        New-InfisicalProject -Name 'backend-api' -Description 'Backend service secrets'

        Creates a project with a description using the session's default organization.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalProject
    .LINK
        Remove-InfisicalProject
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [string] $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession
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

    if ($PSCmdlet.ShouldProcess("Creating project '$Name' in organization '$resolvedOrgId'")) {
        $body = @{
            projectName    = $Name
            organizationId = $resolvedOrgId
        }
        if ($PSBoundParameters.ContainsKey('Description')) {
            $body['projectDescription'] = $Description
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint '/api/v2/workspace' -Body $body -Session $session

        $ws = if ($null -ne $response) {
            if ($response -is [hashtable]) {
                if ($response.ContainsKey('project')) { $response['project'] }
                elseif ($response.ContainsKey('workspace')) { $response['workspace'] }
                else { $null }
            } else {
                if ($null -ne $response.PSObject.Properties['project']) { $response.project }
                elseif ($null -ne $response.PSObject.Properties['workspace']) { $response.workspace }
                else { $null }
            }
        }
        if ($PassThru.IsPresent -and $null -ne $ws) {
            $createdAt = [datetime]::MinValue
            $updatedAt = [datetime]::MinValue
            if ($ws.createdAt) { [void][datetime]::TryParse($ws.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$createdAt) }
            if ($ws.updatedAt) { [void][datetime]::TryParse($ws.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$updatedAt) }

            [PSCustomObject]@{
                PSTypeName = 'InfisicalProject'
                Id         = if ($ws -is [hashtable]) { $ws['id'] } else { $ws.id }
                Name       = if ($ws -is [hashtable]) { $ws['name'] } else { $ws.name }
                Slug       = if ($ws -is [hashtable] -and $ws.ContainsKey('slug')) { $ws['slug'] } elseif ($ws -isnot [hashtable] -and $ws.slug) { $ws.slug } else { '' }
                CreatedAt  = $createdAt
                UpdatedAt  = $updatedAt
            }
        }
    }
}
