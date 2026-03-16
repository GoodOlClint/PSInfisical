# Set-InfisicalIdentity.ps1
# Updates an existing machine identity in Infisical.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalIdentity class, Invoke-InfisicalApi, Get-InfisicalSession

function Set-InfisicalIdentity {
    <#
    .SYNOPSIS
        Updates an existing machine identity in Infisical.

    .DESCRIPTION
        Updates the name, role, delete protection, or metadata of a machine identity.

    .PARAMETER Id
        The ID of the identity to update. Accepts pipeline input by property name.

    .PARAMETER Name
        The new name for the identity.

    .PARAMETER Role
        The new organization-level role.

    .PARAMETER HasDeleteProtection
        Enable or disable delete protection.

    .PARAMETER Metadata
        A hashtable of key-value metadata pairs to set.

    .PARAMETER PassThru
        Return the updated InfisicalIdentity object.

    .EXAMPLE
        Set-InfisicalIdentity -Id 'identity-123' -Name 'renamed-agent'

        Renames a machine identity.

    .EXAMPLE
        Set-InfisicalIdentity -Id 'identity-123' -Role 'admin' -PassThru

        Promotes an identity to admin and returns the updated object.

    .OUTPUTS
        [InfisicalIdentity] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalIdentity
    .LINK
        New-InfisicalIdentity
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalIdentity])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter()]
        [string] $Name,

        [Parameter()]
        [ValidateSet('no-access', 'member', 'admin')]
        [string] $Role,

        [Parameter()]
        [switch] $HasDeleteProtection,

        [Parameter()]
        [hashtable] $Metadata,

        [Parameter()]
        [switch] $PassThru
    )

    process {
        $session = Get-InfisicalSession

        if ($PSCmdlet.ShouldProcess("Updating identity '$Id'")) {
            $body = @{}
            if (-not [string]::IsNullOrEmpty($Name)) { $body['name'] = $Name }
            if (-not [string]::IsNullOrEmpty($Role)) { $body['role'] = $Role }
            if ($PSBoundParameters.ContainsKey('HasDeleteProtection')) { $body['hasDeleteProtection'] = $HasDeleteProtection.IsPresent }

            if ($null -ne $Metadata -and $Metadata.Count -gt 0) {
                $metadataArray = [System.Collections.Generic.List[hashtable]]::new()
                foreach ($key in $Metadata.Keys) {
                    $metadataArray.Add(@{ key = $key; value = [string]$Metadata[$key] })
                }
                $body['metadata'] = @($metadataArray)
            }

            $response = Invoke-InfisicalApi -Method PATCH -Endpoint "/api/v1/identities/$Id" -Body $body -Session $session

            if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.identity) {
                return ConvertTo-InfisicalIdentity -IdentityData $response.identity
            }
        }
    }
}
