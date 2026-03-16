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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Creating project '$Name' in organization '$OrganizationId'")) {
        $body = @{
            projectName    = $Name
            organizationId = $OrganizationId
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint '/api/v2/workspace' -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.workspace) {
            $ws = $response.workspace
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
