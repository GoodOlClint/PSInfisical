# New-InfisicalEnvironment.ps1
# Creates a new environment in an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalEnvironment {
    <#
    .SYNOPSIS
        Creates a new environment in an Infisical project.

    .DESCRIPTION
        Creates an environment with the specified name, slug, and optional position.

    .PARAMETER Name
        The display name of the environment (e.g., "Production").

    .PARAMETER Slug
        The environment slug used in API calls (e.g., "prod"). 1-64 characters.

    .PARAMETER Position
        The display position. Lower numbers appear first.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the created environment object.

    .EXAMPLE
        New-InfisicalEnvironment -Name 'Staging' -Slug 'staging'

        Creates a staging environment in the current project.

    .EXAMPLE
        New-InfisicalEnvironment -Name 'Production' -Slug 'prod' -Position 1 -PassThru

        Creates a production environment at position 1 and returns it.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalEnvironment
    .LINK
        Set-InfisicalEnvironment
    .LINK
        Remove-InfisicalEnvironment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 64)]
        [string] $Slug,

        [Parameter()]
        [int] $Position,

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Creating environment '$Name' (slug: $Slug) in project '$resolvedProjectId'")) {
        $body = @{
            name = $Name
            slug = $Slug
        }

        if ($PSBoundParameters.ContainsKey('Position')) {
            $body['position'] = $Position
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/projects/$resolvedProjectId/environments" -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.environment) {
            $env = $response.environment
            [PSCustomObject]@{
                PSTypeName = 'InfisicalEnvironment'
                Id         = if ($env -is [hashtable]) { $env['id'] } else { $env.id }
                Name       = if ($env -is [hashtable]) { $env['name'] } else { $env.name }
                Slug       = if ($env -is [hashtable]) { $env['slug'] } else { $env.slug }
                Position   = if ($env -is [hashtable] -and $env.ContainsKey('position')) { [int]$env['position'] } elseif ($env -isnot [hashtable] -and $null -ne $env.position) { [int]$env.position } else { 0 }
            }
        }
    }
}
