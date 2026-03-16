# Set-InfisicalTag.ps1
# Updates an existing tag in an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalTag class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalTag {
    <#
    .SYNOPSIS
        Updates an existing tag in an Infisical project.

    .DESCRIPTION
        Updates the slug and/or color of an existing tag. Requires the tag ID.

    .PARAMETER Id
        The ID of the tag to update. Accepts pipeline input by property name.

    .PARAMETER Slug
        The new slug for the tag.

    .PARAMETER Color
        The new display color for the tag.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .PARAMETER PassThru
        Return the updated InfisicalTag object.

    .EXAMPLE
        Set-InfisicalTag -Id 'tag-abc-123' -Color '#0000FF'

        Updates a tag's color.

    .EXAMPLE
        Get-InfisicalTag -Slug 'old-name' | Set-InfisicalTag -Slug 'new-name'

        Renames a tag found via pipeline.

    .OUTPUTS
        [InfisicalTag] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalTag
    .LINK
        New-InfisicalTag
    .LINK
        Remove-InfisicalTag
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalTag])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [ValidateLength(1, 64)]
        [string] $Slug,

        [Parameter()]
        [string] $Color,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ProjectId,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        $session = Get-InfisicalSession

        $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

        if ($PSCmdlet.ShouldProcess("Updating tag '$Id' in project '$resolvedProjectId'")) {
            $body = @{}
            if (-not [string]::IsNullOrEmpty($Slug))  { $body['slug'] = $Slug }
            if (-not [string]::IsNullOrEmpty($Color)) { $body['color'] = $Color }

            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v1/projects/$resolvedProjectId/tags/$Id" -Body $body -Session $session

            if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.tag) {
                return ConvertTo-InfisicalTag -TagData $response.tag -ProjectId $resolvedProjectId
            }
        }
    }
}
