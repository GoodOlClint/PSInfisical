# Set-InfisicalSession.ps1
# Updates properties on the current module-scoped InfisicalSession.
# Called by: User directly, after Connect-Infisical.
# Dependencies: InfisicalSession class, Get-InfisicalSession

function Set-InfisicalSession {
    <#
    .SYNOPSIS
        Updates the current Infisical session defaults.

    .DESCRIPTION
        Modifies the current session's default OrganizationId, ProjectId, and/or
        Environment without reconnecting. Useful when connecting without these values
        and setting them after discovery, or when switching contexts.

    .PARAMETER OrganizationId
        Sets the default organization ID for subsequent commands.

    .PARAMETER ProjectId
        Sets the default project ID for subsequent commands.

    .PARAMETER Environment
        Sets the default environment slug for subsequent commands.

    .PARAMETER PassThru
        If specified, returns the updated InfisicalSession object.

    .EXAMPLE
        $org = Get-InfisicalOrganization | Select-Object -First 1
        Set-InfisicalSession -OrganizationId $org.Id

        Sets the session's default organization after discovery.

    .EXAMPLE
        $project = Get-InfisicalProject | Where-Object Name -eq 'worklab'
        Set-InfisicalSession -ProjectId $project.Id

        Sets the session's default project after discovery.

    .EXAMPLE
        Set-InfisicalSession -Environment 'staging'

        Switches the default environment to staging.

    .OUTPUTS
        [InfisicalSession] when -PassThru is specified; otherwise, no output.

    .LINK
        Connect-Infisical
    .LINK
        Get-InfisicalProject
    .LINK
        Get-InfisicalOrganization
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Modifies in-memory session state only, no external side effects')]
    [CmdletBinding()]
    [OutputType([InfisicalSession])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string] $Environment,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    if (-not $PSBoundParameters.ContainsKey('OrganizationId') -and -not $PSBoundParameters.ContainsKey('ProjectId') -and -not $PSBoundParameters.ContainsKey('Environment')) {
        Write-Warning 'Set-InfisicalSession: No parameters specified. Use -OrganizationId, -ProjectId, and/or -Environment to update the session.'
        return
    }

    if ($PSBoundParameters.ContainsKey('OrganizationId')) {
        Write-Verbose "Set-InfisicalSession: Setting OrganizationId to '$OrganizationId'"
        $session.OrganizationId = $OrganizationId
    }

    if ($PSBoundParameters.ContainsKey('ProjectId')) {
        Write-Verbose "Set-InfisicalSession: Setting ProjectId to '$ProjectId'"
        $session.ProjectId = $ProjectId
    }

    if ($PSBoundParameters.ContainsKey('Environment')) {
        Write-Verbose "Set-InfisicalSession: Setting DefaultEnvironment to '$Environment'"
        $session.DefaultEnvironment = $Environment
    }

    if ($PassThru.IsPresent) {
        return $session
    }
}
