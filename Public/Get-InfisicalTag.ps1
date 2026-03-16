# Get-InfisicalTag.ps1
# Retrieves tags from an Infisical project.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalTag class, Invoke-InfisicalApi, Get-InfisicalSession

function Get-InfisicalTag {
    <#
    .SYNOPSIS
        Retrieves tags from an Infisical project.

    .DESCRIPTION
        Fetches tags from the specified project. Tags are used to categorize and
        filter secrets. Use -Id or -Slug to retrieve a specific tag.

    .PARAMETER Id
        The tag ID to retrieve.

    .PARAMETER Slug
        The tag slug to retrieve.

    .PARAMETER ProjectId
        The project/workspace ID. Overrides the session default if specified.

    .EXAMPLE
        Get-InfisicalTag

        Returns all tags in the current project.

    .EXAMPLE
        Get-InfisicalTag -Slug 'production'

        Returns the tag with slug "production".

    .EXAMPLE
        Get-InfisicalTag -Id 'tag-abc-123'

        Returns a specific tag by ID.

    .OUTPUTS
        [InfisicalTag] or [InfisicalTag[]]

    .LINK
        New-InfisicalTag
    .LINK
        Set-InfisicalTag
    .LINK
        Remove-InfisicalTag
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([InfisicalTag], [InfisicalTag[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory, ParameterSetName = 'BySlug')]
        [ValidateNotNullOrEmpty()]
        [string] $Slug,

        [Parameter()]
        [string] $ProjectId
    )

    $session = Get-InfisicalSession

    $resolvedProjectId = if ([string]::IsNullOrEmpty($ProjectId)) { $session.ProjectId } else { $ProjectId }

    switch ($PSCmdlet.ParameterSetName) {
        'ById' {
            $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/projects/$resolvedProjectId/tags/$Id" -Session $session

            if ($null -eq $response -or $null -eq $response.tag) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new("Tag '$Id' not found."),
                    'InfisicalTagNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Id
                )
                $PSCmdlet.WriteError($errorRecord)
                return
            }

            return ConvertTo-InfisicalTag -TagData $response.tag -ProjectId $resolvedProjectId
        }
        'BySlug' {
            $encodedSlug = [System.Uri]::EscapeDataString($Slug)
            $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/projects/$resolvedProjectId/tags/slug/$encodedSlug" -Session $session

            if ($null -eq $response -or $null -eq $response.tag) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Management.Automation.ItemNotFoundException]::new("Tag with slug '$Slug' not found."),
                    'InfisicalTagNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Slug
                )
                $PSCmdlet.WriteError($errorRecord)
                return
            }

            return ConvertTo-InfisicalTag -TagData $response.tag -ProjectId $resolvedProjectId
        }
        default {
            # List all tags
            $response = Invoke-InfisicalApi -Method GET -Endpoint "/api/v1/projects/$resolvedProjectId/tags" -Session $session

            if ($null -eq $response -or $null -eq $response.tags) {
                return
            }

            foreach ($tagData in $response.tags) {
                ConvertTo-InfisicalTag -TagData $tagData -ProjectId $resolvedProjectId
            }
        }
    }
}
