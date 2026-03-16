# New-InfisicalIdentity.ps1
# Creates a new machine identity in an Infisical organization.
# Called by: User directly.
# Dependencies: InfisicalSession class, InfisicalIdentity class, Invoke-InfisicalApi, Get-InfisicalSession

function New-InfisicalIdentity {
    <#
    .SYNOPSIS
        Creates a new machine identity in Infisical.

    .DESCRIPTION
        Creates a machine identity for programmatic API access. After creation,
        attach an authentication method with Add-InfisicalIdentityAuth and generate
        credentials with New-InfisicalClientSecret.

    .PARAMETER Name
        The name of the identity to create.

    .PARAMETER OrganizationId
        The organization ID to create the identity in.

    .PARAMETER Role
        The organization-level role. Defaults to 'no-access'.

    .PARAMETER HasDeleteProtection
        Prevent the identity from being deleted.

    .PARAMETER Metadata
        A hashtable of key-value metadata pairs.

    .PARAMETER PassThru
        Return the created InfisicalIdentity object.

    .EXAMPLE
        New-InfisicalIdentity -Name 'deploy-agent' -OrganizationId 'org-123' -PassThru

        Creates a machine identity and returns it.

    .EXAMPLE
        New-InfisicalIdentity -Name 'ci-runner' -OrganizationId 'org-123' -Role 'member'

        Creates a machine identity with the member role.

    .OUTPUTS
        [InfisicalIdentity] when -PassThru is specified; otherwise, no output.

    .LINK
        Get-InfisicalIdentity
    .LINK
        Add-InfisicalIdentityAuth
    .LINK
        New-InfisicalClientSecret
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([InfisicalIdentity])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationId,

        [Parameter()]
        [ValidateSet('no-access', 'member', 'admin')]
        [string] $Role = 'no-access',

        [Parameter()]
        [switch] $HasDeleteProtection,

        [Parameter()]
        [hashtable] $Metadata,

        [Parameter()]
        [switch] $PassThru
    )

    $session = Get-InfisicalSession

    if ($PSCmdlet.ShouldProcess("Creating identity '$Name' in organization '$OrganizationId'")) {
        $body = @{
            name           = $Name
            organizationId = $OrganizationId
            role           = $Role
        }

        if ($HasDeleteProtection.IsPresent) {
            $body['hasDeleteProtection'] = $true
        }

        if ($null -ne $Metadata -and $Metadata.Count -gt 0) {
            $metadataArray = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($key in $Metadata.Keys) {
                $metadataArray.Add(@{ key = $key; value = [string]$Metadata[$key] })
            }
            $body['metadata'] = @($metadataArray)
        }

        $response = Invoke-InfisicalApi -Method POST -Endpoint '/api/v1/identities' -Body $body -Session $session

        if ($PassThru.IsPresent -and $null -ne $response -and $null -ne $response.identity) {
            return ConvertTo-InfisicalIdentity -IdentityData $response.identity
        }
    }
}
