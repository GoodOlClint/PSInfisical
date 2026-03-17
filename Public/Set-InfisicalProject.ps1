# Set-InfisicalProject.ps1
# Updates a project/workspace in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalProject {
    <#
    .SYNOPSIS
        Updates a project in Infisical.

    .DESCRIPTION
        Modifies properties of an existing project, such as its name or auto-capitalization setting.

    .PARAMETER Id
        The ID of the project to update.

    .PARAMETER Name
        The new name for the project.

    .PARAMETER AutoCapitalization
        Whether to auto-capitalize secret names in this project.

    .PARAMETER PassThru
        If specified, returns the updated project object.

    .EXAMPLE
        Set-InfisicalProject -Id 'proj-abc-123' -Name 'new-name' -PassThru

        Renames a project and returns the updated object.

    .OUTPUTS
        PSCustomObject when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalProject
    .LINK
        New-InfisicalProject
    .LINK
        Remove-InfisicalProject
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter()]
        [bool] $AutoCapitalization,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        $session = Get-InfisicalSession

        $body = @{}
        if ($PSBoundParameters.ContainsKey('Name')) {
            $body['name'] = $Name
        }
        if ($PSBoundParameters.ContainsKey('AutoCapitalization')) {
            $body['autoCapitalization'] = $AutoCapitalization
        }

        if ($body.Count -eq 0) {
            Write-Warning 'Set-InfisicalProject: No properties specified to update.'
            return
        }

        if ($PSCmdlet.ShouldProcess("Updating project '$Id'")) {
            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v2/workspace/$Id" -Body $body -Session $session

            if ($PassThru.IsPresent -and $null -ne $response) {
                $ws = if ($response -is [hashtable]) {
                    if ($response.ContainsKey('project')) { $response['project'] }
                    elseif ($response.ContainsKey('workspace')) { $response['workspace'] }
                    else { $null }
                } else {
                    if ($null -ne $response.PSObject.Properties['project']) { $response.project }
                    elseif ($null -ne $response.PSObject.Properties['workspace']) { $response.workspace }
                    else { $null }
                }
                if ($null -ne $ws) {
                    ConvertTo-InfisicalProjectObject -Data $ws
                }
            }
        }
    }
}
