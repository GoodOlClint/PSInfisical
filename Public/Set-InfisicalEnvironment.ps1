# Set-InfisicalEnvironment.ps1
# Updates an environment in an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalEnvironment {
    <#
    .SYNOPSIS
        Updates an environment in an Infisical project.

    .DESCRIPTION
        Updates the name, slug, or position of an existing environment.

    .PARAMETER Id
        The ID of the environment to update.

    .PARAMETER Name
        The new display name.

    .PARAMETER Slug
        The new slug.

    .PARAMETER Position
        The new display position.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the updated environment object.

    .EXAMPLE
        Set-InfisicalEnvironment -Id 'env-123' -Name 'Pre-Production' -Slug 'pre-prod'

        Renames an environment.

    .EXAMPLE
        Set-InfisicalEnvironment -Id 'env-123' -Position 2 -PassThru

        Moves an environment to position 2 and returns the updated object.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalEnvironment
    .LINK
        New-InfisicalEnvironment
    .LINK
        Remove-InfisicalEnvironment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [string] $Name,

        [Parameter()]
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

    if ($PSCmdlet.ShouldProcess("Updating environment '$Id' in project '$resolvedProjectId'")) {
        $body = @{}
        if (-not [string]::IsNullOrEmpty($Name)) { $body['name'] = $Name }
        if (-not [string]::IsNullOrEmpty($Slug)) { $body['slug'] = $Slug }
        if ($PSBoundParameters.ContainsKey('Position')) { $body['position'] = $Position }

        $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v1/projects/$resolvedProjectId/environments/$Id" -Body $body -Session $session

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
