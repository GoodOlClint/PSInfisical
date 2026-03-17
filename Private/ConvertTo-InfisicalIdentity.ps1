# ConvertTo-InfisicalIdentity.ps1
# Converts an Infisical API identity response into an InfisicalIdentity instance.
# Called by: Public identity functions.
# Dependencies: InfisicalIdentity class

function ConvertTo-InfisicalIdentity {
    [CmdletBinding()]
    [OutputType([InfisicalIdentity])]
    param(
        [Parameter(Mandatory)]
        [PSObject] $IdentityData
    )

    $identity = [InfisicalIdentity]::new()

    $identity.Id = if ($IdentityData -is [hashtable]) {
        if ($IdentityData.ContainsKey('id')) { $IdentityData['id'] } else { '' }
    } else {
        if ($IdentityData.id) { $IdentityData.id } else { '' }
    }

    $identity.Name = if ($IdentityData -is [hashtable]) {
        if ($IdentityData.ContainsKey('name')) { $IdentityData['name'] } else { '' }
    } else {
        $prop = $IdentityData.PSObject.Properties['name']
        if ($null -ne $prop) { $prop.Value } else { '' }
    }

    # OrgId may come as 'orgId' or 'organizationId'
    $orgId = if ($IdentityData -is [hashtable]) {
        if ($IdentityData.ContainsKey('orgId')) { $IdentityData['orgId'] }
        elseif ($IdentityData.ContainsKey('organizationId')) { $IdentityData['organizationId'] }
        else { '' }
    } else {
        if ($null -ne $IdentityData.PSObject.Properties['orgId']) { $IdentityData.orgId }
        elseif ($null -ne $IdentityData.PSObject.Properties['organizationId']) { $IdentityData.organizationId }
        else { '' }
    }
    $identity.OrganizationId = $orgId

    $identity.Role = if ($IdentityData -is [hashtable]) {
        if ($IdentityData.ContainsKey('role')) { $IdentityData['role'] } else { '' }
    } else {
        $prop = $IdentityData.PSObject.Properties['role']
        if ($null -ne $prop) { $prop.Value } else { '' }
    }

    # Auth methods array
    $hasAuthMethods = if ($IdentityData -is [hashtable]) { $IdentityData.ContainsKey('authMethods') } else { $null -ne $IdentityData.PSObject.Properties['authMethods'] }
    if ($hasAuthMethods -and $null -ne $IdentityData.authMethods) {
        $identity.AuthMethods = @($IdentityData.authMethods)
    }

    # Delete protection
    $hasProtection = if ($IdentityData -is [hashtable]) { $IdentityData.ContainsKey('hasDeleteProtection') } else { $null -ne $IdentityData.PSObject.Properties['hasDeleteProtection'] }
    $identity.HasDeleteProtection = if ($hasProtection) { [bool]$IdentityData.hasDeleteProtection } else { $false }

    # Metadata
    $hasMeta = if ($IdentityData -is [hashtable]) { $IdentityData.ContainsKey('metadata') } else { $null -ne $IdentityData.PSObject.Properties['metadata'] }
    if ($hasMeta -and $null -ne $IdentityData.metadata -and @($IdentityData.metadata).Count -gt 0) {
        $ht = @{}
        foreach ($entry in $IdentityData.metadata) {
            $k = if ($entry -is [hashtable]) { $entry['key'] } else { $entry.key }
            $v = if ($entry -is [hashtable]) { $entry['value'] } else { $entry.value }
            if ($k) { $ht[$k] = $v }
        }
        $identity.Metadata = $ht
    }

    # Timestamps
    $parsedDate = [datetime]::MinValue
    if ($IdentityData.createdAt -and [datetime]::TryParse($IdentityData.createdAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $identity.CreatedAt = $parsedDate
    }
    if ($IdentityData.updatedAt -and [datetime]::TryParse($IdentityData.updatedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        $identity.UpdatedAt = $parsedDate
    }

    return $identity
}
