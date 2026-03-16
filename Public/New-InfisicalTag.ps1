# New-InfisicalTag.ps1
# Creates a new tag in an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalTag class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalTag {
    <#
    .SYNOPSIS
        Creates a new tag in an Infisical project.

    .DESCRIPTION
        Creates a tag with the specified slug and color. Tags can be attached to
        secrets for categorization and filtering.

    .PARAMETER Slug
        The slug identifier for the tag (1-64 characters).

    .PARAMETER Color
        The display color for the tag (e.g., '#FF0000').

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the created InfisicalTag object.

    .EXAMPLE
        New-InfisicalTag -Slug 'production' -Color '#FF0000'

        Creates a tag with slug "production" and red color.

    .EXAMPLE
        New-InfisicalTag -Slug 'database' -Color '#00FF00' -PassThru

        Creates a tag and returns the created object.

    .OUTPUTS
        [InfisicalTag] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalTag
    .LINK
        Set-InfisicalTag
    .LINK
        Remove-InfisicalTag
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalTag])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 64)]
        [string] $Slug,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        [Parameter()]
        [string] $ProjectId,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    if ($PSCmdlet.ShouldProcess("Creating tag '$Slug' with color '$Color' in project '$resolvedProjectId'")) {
        $body = @{
            slug  = $Slug
            color = $Color
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint "/api/v1/projects/$resolvedProjectId/tags" -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.tag) {
            return ConvertTo-InfisicalTag -TagData $response.tag -ProjectId $resolvedProjectId
        }
    }
}
