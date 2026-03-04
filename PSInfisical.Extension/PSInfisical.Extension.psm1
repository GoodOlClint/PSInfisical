# PSInfisical.Extension.psm1
# SecretManagement vault extension for PSInfisical.
# Provides the 5 required functions: Get-Secret, Set-Secret, Remove-Secret,
# Get-SecretInfo, Test-SecretVault.
# Called by: Microsoft.PowerShell.SecretManagement when a registered vault is accessed.
# Dependencies: PSInfisical module (parent), Microsoft.PowerShell.SecretManagement

#Requires -Version 5.1

Set-StrictMode -Version Latest

# The parent PSInfisical module's functions (Connect-Infisical, Get-InfisicalSecret, etc.)
# are available because this module is loaded as a NestedModule of PSInfisical.psd1.
# Do NOT import the parent here — that would create a circular dependency.

# Session cache: keyed by vault name, value is an InfisicalSession object.
# Avoids re-authenticating on every SecretManagement call.
$script:SessionCache = @{}

# ---------------------------------------------------------------------------
# Internal helpers (not exported)
# ---------------------------------------------------------------------------

function Get-OrCreateSession {
    <#
    .SYNOPSIS
        Ensures a valid PSInfisical session exists for the specified vault.

    .DESCRIPTION
        Checks the session cache for an existing, non-expired session for the
        given vault name. If found, injects it into the PSInfisical module scope.
        If not found or expired, authenticates using credentials from
        AdditionalParameters and caches the new session.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $VaultName,

        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    # Check for a cached session that is still valid
    if ($script:SessionCache.ContainsKey($VaultName)) {
        $cachedSession = $script:SessionCache[$VaultName]
        $cachedSession.UpdateConnectionStatus()
        if ($cachedSession.Connected -and -not $cachedSession.IsTokenExpiringSoon()) {
            # Inject cached session into PSInfisical module scope
            & (Get-Module PSInfisical) { param($s) $script:InfisicalSession = $s } $cachedSession
            return
        }
        # Session expired or expiring — will re-authenticate below
    }

    # Extract connection parameters with defaults
    $apiUrl      = if ($AdditionalParameters.ContainsKey('ApiUrl'))      { $AdditionalParameters['ApiUrl'] }      else { 'https://app.infisical.com' }
    $projectId   = $AdditionalParameters['ProjectId']
    $environment = if ($AdditionalParameters.ContainsKey('Environment')) { $AdditionalParameters['Environment'] } else { 'prod' }

    # Validate required parameters
    if ([string]::IsNullOrEmpty($projectId)) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new("Vault '$VaultName': VaultParameters must include 'ProjectId'."),
            'InfisicalVaultMissingProjectId',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $VaultName
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    # Build Connect-Infisical parameters
    $connectParams = @{
        ApiUrl      = $apiUrl
        ProjectId   = $projectId
        Environment = $environment
        PassThru    = $true
    }

    # Determine auth method from provided parameters
    if ($AdditionalParameters.ContainsKey('ClientId') -and $AdditionalParameters.ContainsKey('ClientSecret')) {
        $connectParams['ClientId'] = $AdditionalParameters['ClientId']
        $connectParams['ClientSecret'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['ClientSecret']
    }
    elseif ($AdditionalParameters.ContainsKey('Token')) {
        $connectParams['Token'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['Token']
    }
    elseif ($AdditionalParameters.ContainsKey('AccessToken')) {
        $connectParams['AccessToken'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['AccessToken']
    }
    else {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new("Vault '$VaultName': VaultParameters must include authentication credentials (ClientId+ClientSecret, Token, or AccessToken)."),
            'InfisicalVaultMissingCredentials',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $VaultName
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    # Null out the PSInfisical module's session to prevent Connect-Infisical
    # from disposing a cached session belonging to a different vault.
    & (Get-Module PSInfisical) { $script:InfisicalSession = $null }

    $session = Connect-Infisical @connectParams
    $script:SessionCache[$VaultName] = $session
}

function ConvertTo-SessionSecureString {
    <#
    .SYNOPSIS
        Converts a value to SecureString if it is not already one.

    .DESCRIPTION
        Register-SecretVault -VaultParameters stores values as their original
        types. Users may pass plain strings or SecureStrings for credentials.
        This helper normalises both to SecureString.

    .OUTPUTS
        [System.Security.SecureString]
    #>
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory)]
        [object] $Value
    )

    if ($Value -is [System.Security.SecureString]) {
        return $Value
    }

    $secureString = [System.Security.SecureString]::new()
    foreach ($char in $Value.ToString().ToCharArray()) {
        $secureString.AppendChar($char)
    }
    $secureString.MakeReadOnly()
    return $secureString
}

function Resolve-SecretPath {
    <#
    .SYNOPSIS
        Returns the secret path from AdditionalParameters or the default '/'.

    .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    if ($AdditionalParameters.ContainsKey('SecretPath') -and -not [string]::IsNullOrEmpty($AdditionalParameters['SecretPath'])) {
        return $AdditionalParameters['SecretPath']
    }
    return '/'
}

# ---------------------------------------------------------------------------
# Required SecretManagement extension functions
# ---------------------------------------------------------------------------

function Get-Secret {
    <#
    .SYNOPSIS
        Retrieves a secret value from Infisical.

    .DESCRIPTION
        Called by Microsoft.PowerShell.SecretManagement when the user runs
        Get-Secret -Vault <VaultName>. Returns the secret value as a
        SecureString, or $null if the secret does not exist.

    .OUTPUTS
        [System.Security.SecureString]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $VaultName,

        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    Get-OrCreateSession -VaultName $VaultName -AdditionalParameters $AdditionalParameters
    $secretPath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters

    $secret = Get-InfisicalSecret -Name $Name -SecretPath $secretPath -ErrorAction SilentlyContinue
    if ($null -eq $secret) {
        return $null
    }
    return $secret.Value
}

function Set-Secret {
    <#
    .SYNOPSIS
        Creates or updates a secret in Infisical.

    .DESCRIPTION
        Called by Microsoft.PowerShell.SecretManagement when the user runs
        Set-Secret -Vault <VaultName>. Checks whether the secret exists first,
        then updates or creates accordingly.

    .OUTPUTS
        [bool]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function signature is defined by SecretManagement')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [object] $Secret,

        [Parameter(Mandatory)]
        [string] $VaultName,

        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    Get-OrCreateSession -VaultName $VaultName -AdditionalParameters $AdditionalParameters
    $secretPath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters

    # Normalise the secret value to SecureString
    $secureValue = ConvertTo-SessionSecureString -Value $Secret

    # Check if the secret already exists to determine create vs update
    $existing = Get-InfisicalSecret -Name $Name -SecretPath $secretPath -ErrorAction SilentlyContinue

    if ($null -ne $existing) {
        Set-InfisicalSecret -Name $Name -Value $secureValue -SecretPath $secretPath -Confirm:$false -ErrorAction Stop
    }
    else {
        New-InfisicalSecret -Name $Name -Value $secureValue -SecretPath $secretPath -Confirm:$false -ErrorAction Stop
    }

    return $true
}

function Remove-Secret {
    <#
    .SYNOPSIS
        Removes a secret from Infisical.

    .DESCRIPTION
        Called by Microsoft.PowerShell.SecretManagement when the user runs
        Remove-Secret -Vault <VaultName>.

    .OUTPUTS
        [bool]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function signature is defined by SecretManagement')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $VaultName,

        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    Get-OrCreateSession -VaultName $VaultName -AdditionalParameters $AdditionalParameters
    $secretPath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters

    Remove-InfisicalSecret -Name $Name -SecretPath $secretPath -Confirm:$false -ErrorAction Stop

    return $true
}

function Get-SecretInfo {
    <#
    .SYNOPSIS
        Lists secrets in Infisical as SecretInformation objects.

    .DESCRIPTION
        Called by Microsoft.PowerShell.SecretManagement when the user runs
        Get-SecretInfo -Vault <VaultName>. Returns metadata about secrets
        without exposing their values.

    .OUTPUTS
        [Microsoft.PowerShell.SecretManagement.SecretInformation]
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Filter,

        [Parameter(Mandatory)]
        [string] $VaultName,

        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    Get-OrCreateSession -VaultName $VaultName -AdditionalParameters $AdditionalParameters
    $secretPath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters

    $secrets = Get-InfisicalSecrets -SecretPath $secretPath -ErrorAction Stop

    if ($null -eq $secrets) {
        return @()
    }

    # Apply wildcard filter if provided
    if (-not [string]::IsNullOrEmpty($Filter)) {
        $secrets = @($secrets | Where-Object { $_.Name -like $Filter })
    }

    # Resolve SecretManagement types at runtime rather than parse time.
    # When this module is loaded as a NestedModule of PSInfisical, SecretManagement
    # may not yet be imported, causing parse-time [type] literals to fail.
    $SecretInfoType = 'Microsoft.PowerShell.SecretManagement.SecretInformation' -as [type]
    $SecureStringType = ('Microsoft.PowerShell.SecretManagement.SecretType' -as [type])::SecureString

    foreach ($s in $secrets) {
        $SecretInfoType::new(
            $s.Name,
            $SecureStringType,
            $VaultName
        )
    }
}

function Test-SecretVault {
    <#
    .SYNOPSIS
        Tests whether the Infisical vault is accessible.

    .DESCRIPTION
        Called by Microsoft.PowerShell.SecretManagement when the user runs
        Test-SecretVault -Name <VaultName>. Validates authentication and
        API connectivity by listing secrets.

    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $VaultName,

        [Parameter(Mandatory)]
        [hashtable] $AdditionalParameters
    )

    try {
        Get-OrCreateSession -VaultName $VaultName -AdditionalParameters $AdditionalParameters
        $secretPath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters

        # Attempt a lightweight API call to verify connectivity and permissions
        $null = Get-InfisicalSecrets -SecretPath $secretPath -ErrorAction Stop
        return $true
    }
    catch {
        Write-Verbose "Test-SecretVault: Vault '$VaultName' test failed: $($_.Exception.Message)"
        return $false
    }
}
