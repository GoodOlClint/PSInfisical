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

# Reserved metadata key used to record the original SecretManagement SecretType.
# Lets Get-Secret deserialize a stored secret back into the same shape (e.g.
# PSCredential, Hashtable) the caller originally handed to Set-Secret.
$script:TypeTagKey = 'PSInfisicalSecretType'

# Marker placed in serialised Hashtable values so nested SecureStrings can be
# rebuilt during ConvertFrom-InfisicalSecretPayload.
$script:SecureStringMarkerKey = '__PSInfisicalSecureString__'

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
    elseif ($AdditionalParameters.ContainsKey('AWSIdentityDocument')) {
        $connectParams['AWSIdentityDocument'] = $AdditionalParameters['AWSIdentityDocument']
    }
    elseif ($AdditionalParameters.ContainsKey('AzureJwt')) {
        $connectParams['AzureJwt'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['AzureJwt']
    }
    elseif ($AdditionalParameters.ContainsKey('GCPIdentityToken')) {
        $connectParams['GCPIdentityToken'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['GCPIdentityToken']
    }
    elseif ($AdditionalParameters.ContainsKey('KubernetesServiceAccountToken') -and $AdditionalParameters.ContainsKey('KubernetesIdentityId')) {
        $connectParams['KubernetesServiceAccountToken'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['KubernetesServiceAccountToken']
        $connectParams['KubernetesIdentityId'] = $AdditionalParameters['KubernetesIdentityId']
    }
    elseif ($AdditionalParameters.ContainsKey('OIDCToken') -and $AdditionalParameters.ContainsKey('OIDCIdentityId')) {
        $connectParams['OIDCToken'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['OIDCToken']
        $connectParams['OIDCIdentityId'] = $AdditionalParameters['OIDCIdentityId']
    }
    elseif ($AdditionalParameters.ContainsKey('Jwt') -and $AdditionalParameters.ContainsKey('JwtIdentityId')) {
        $connectParams['Jwt'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['Jwt']
        $connectParams['JwtIdentityId'] = $AdditionalParameters['JwtIdentityId']
    }
    elseif ($AdditionalParameters.ContainsKey('LDAPUsername') -and $AdditionalParameters.ContainsKey('LDAPPassword')) {
        $connectParams['LDAPUsername'] = $AdditionalParameters['LDAPUsername']
        $connectParams['LDAPPassword'] = ConvertTo-SessionSecureString -Value $AdditionalParameters['LDAPPassword']
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

function Resolve-InfisicalName {
    <#
    .SYNOPSIS
        Splits a SecretManagement -Name into an Infisical key + secret path.

    .DESCRIPTION
        SecretManagement's API exposes only a single -Name parameter, but Infisical
        models secrets as (key, secretPath). Callers that want hierarchical naming
        (e.g. 'team/role/host') would otherwise have the slash-bearing name rejected
        by the Infisical API, whose keys must be identifier-shaped.

        This helper splits -Name on its last '/'. The prefix (if any) is appended
        to the vault's configured SecretPath; the final segment becomes the bare
        key. A leading '/' on -Name is treated as 'relative to BasePath' rather
        than absolute — vault isolation always wins.

    .OUTPUTS
        [hashtable] with keys Name (bare key) and SecretPath (absolute folder path).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $BasePath
    )

    $base = $BasePath.TrimEnd('/')
    if ([string]::IsNullOrEmpty($base)) { $base = '' }

    $lastSlash = $Name.LastIndexOf('/')
    if ($lastSlash -lt 0) {
        $resolvedPath = if ([string]::IsNullOrEmpty($base)) { '/' } else { $base }
        return @{ Name = $Name; SecretPath = $resolvedPath }
    }

    $key = $Name.Substring($lastSlash + 1)
    if ([string]::IsNullOrEmpty($key)) {
        throw [System.ArgumentException]::new(
            "Secret name '$Name' is invalid: it ends with '/'. The final segment must be a non-empty key.",
            'Name'
        )
    }

    $relPrefix = $Name.Substring(0, $lastSlash).Trim('/')
    if ([string]::IsNullOrEmpty($relPrefix)) {
        $resolvedPath = if ([string]::IsNullOrEmpty($base)) { '/' } else { $base }
    }
    elseif ([string]::IsNullOrEmpty($base)) {
        $resolvedPath = "/$relPrefix"
    }
    else {
        $resolvedPath = "$base/$relPrefix"
    }

    return @{ Name = $key; SecretPath = $resolvedPath }
}

function Initialize-InfisicalFolderPath {
    <#
    .SYNOPSIS
        Idempotently creates each folder segment along an absolute Infisical path.

    .DESCRIPTION
        Walks $TargetPath segment by segment, calling New-InfisicalFolder for each.
        Existing folders surface as API errors which are downgraded to verbose
        messages — any genuine failure (e.g. permissions) is re-surfaced when the
        secret write itself fails. Idempotent, so Set-Secret can call it on every
        write without worrying about pre-existing paths.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $TargetPath
    )

    if ([string]::IsNullOrEmpty($TargetPath) -or $TargetPath -eq '/') {
        return
    }

    $segments = $TargetPath.Trim('/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
    $currentPath = '/'
    foreach ($segment in $segments) {
        try {
            New-InfisicalFolder -Name $segment -SecretPath $currentPath -Confirm:$false -ErrorAction Stop | Out-Null
        }
        catch {
            # Only swallow conflict-shaped errors (folder already exists); rethrow
            # everything else so the caller sees permission/network/server
            # failures at the right layer instead of as a cryptic downstream
            # secret-write error.
            $msg = [string]$_.Exception.Message
            if ($msg -notmatch '(?i)already\s*exists|conflict|duplicate|HTTP\s*409|HTTP\s*400') {
                throw
            }
            Write-Verbose "Initialize-InfisicalFolderPath: folder '$segment' at '$currentPath' already exists; skipping. ($msg)"
        }
        $currentPath = if ($currentPath -eq '/') { "/$segment" } else { "$currentPath/$segment" }
    }
}

function Unprotect-SecureString {
    <#
    .SYNOPSIS
        Returns the plaintext value of a SecureString and zeros the unmanaged
        buffer immediately after the copy.

    .DESCRIPTION
        SecretManagement values pass through plaintext on their way into
        Infisical's JSON storage model — there is no avoiding the managed string
        allocation. The next-best thing is to ensure the unmanaged buffer that
        backed the SecureString is wiped right away rather than waiting for
        NetworkCredential's finalizer to run on a future GC pass.

        The managed string returned by this function still lives until garbage
        collection (PowerShell's string interning makes it impossible to wipe
        deterministically), but the window between extraction and managed-heap
        clearing is narrowed, and the unmanaged buffer is never reachable after
        return.

    .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Security.SecureString] $Secret
    )

    $bstr = [System.IntPtr]::Zero
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Secret)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
    }
    finally {
        if ($bstr -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($bstr)
        }
    }
}

function ConvertTo-HashtableTree {
    <#
    .SYNOPSIS
        Recursively converts PSCustomObject nodes in a deserialised JSON graph
        into Hashtables, preserving arrays and primitives in place.

    .DESCRIPTION
        ConvertFrom-Json emits PSCustomObject for every JSON object. When a
        caller stored @{ a = @{ b = 1 } } on Set-Secret, Get-Secret should give
        them a Hashtable of Hashtables back, not a Hashtable wrapping a
        PSCustomObject. This walks the graph and rebuilds nested objects as
        Hashtables, leaving the SecureString marker sentinel untouched (its
        caller in ConvertFrom-InfisicalSecretPayload inspects it directly).

    .OUTPUTS
        [object] — same shape as the input with PSCustomObject nodes replaced
        by Hashtables.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $ht[$prop.Name] = ConvertTo-HashtableTree -InputObject $prop.Value
        }
        return $ht
    }

    if ($InputObject -is [System.Collections.IList] -and -not ($InputObject -is [string])) {
        $list = foreach ($item in $InputObject) {
            ConvertTo-HashtableTree -InputObject $item
        }
        return ,@($list)
    }

    return $InputObject
}

function ConvertTo-InfisicalSecretPayload {
    <#
    .SYNOPSIS
        Serialises a SecretManagement -Secret value to Infisical's single-string
        storage model, returning the payload and a type tag for round-tripping.

    .DESCRIPTION
        Infisical secrets are a single opaque string per key. SecretManagement
        allows five SecretTypes (ByteArray, String, SecureString, PSCredential,
        Hashtable). This helper normalises whichever the caller passed into a
        plaintext string plus a type tag, so ConvertFrom-InfisicalSecretPayload
        can rebuild the original type on read.

        For Hashtable inputs, nested SecureString values are converted to
        plaintext with a marker object so they too can be rebuilt.

    .OUTPUTS
        [hashtable] with keys Value (string) and Type (one of String,
        SecureString, PSCredential, Hashtable, ByteArray).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'SecureString contents are intentionally serialised for storage; protection is provided by Infisical at rest.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Secret
    )

    if ($Secret -is [System.Security.SecureString]) {
        return @{
            Value = Unprotect-SecureString -Secret $Secret
            Type  = 'SecureString'
        }
    }

    if ($Secret -is [System.Management.Automation.PSCredential]) {
        $pwPlain = Unprotect-SecureString -Secret $Secret.Password
        $json = @{ UserName = $Secret.UserName; Password = $pwPlain } | ConvertTo-Json -Compress
        return @{ Value = $json; Type = 'PSCredential' }
    }

    if ($Secret -is [byte[]]) {
        return @{
            Value = [System.Convert]::ToBase64String($Secret)
            Type  = 'ByteArray'
        }
    }

    if ($Secret -is [System.Collections.IDictionary]) {
        $serialised = @{}
        foreach ($key in $Secret.Keys) {
            $value = $Secret[$key]
            if ($value -is [System.Security.SecureString]) {
                $serialised[[string]$key] = @{
                    $script:SecureStringMarkerKey = $true
                    v = Unprotect-SecureString -Secret $value
                }
            }
            else {
                $serialised[[string]$key] = $value
            }
        }
        $json = $serialised | ConvertTo-Json -Compress -Depth 10
        return @{ Value = $json; Type = 'Hashtable' }
    }

    if ($Secret -is [string]) {
        return @{ Value = $Secret; Type = 'String' }
    }

    throw [System.ArgumentException]::new(
        "Unsupported -Secret type '$($Secret.GetType().FullName)'. SecretManagement supports byte[], String, SecureString, PSCredential, and Hashtable.",
        'Secret'
    )
}

function ConvertFrom-InfisicalSecretPayload {
    <#
    .SYNOPSIS
        Rebuilds a SecretManagement-typed value from a stored Infisical secret.

    .DESCRIPTION
        Inverse of ConvertTo-InfisicalSecretPayload. When the type tag is missing
        (e.g. legacy or UI-created secrets) the value is returned as a
        SecureString — that was the extension's behaviour before typed payloads
        were introduced and preserves backward compatibility.

        For 'Hashtable' payloads, nested JSON objects are recursively converted
        back into Hashtables so the input/output shape is symmetric: what the
        caller handed to Set-Secret is what they get back from Get-Secret.

    .OUTPUTS
        [object] — concrete type depends on $Type.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value,

        [Parameter()]
        [string] $Type
    )

    if ([string]::IsNullOrEmpty($Type) -or $Type -eq 'SecureString') {
        return ConvertTo-PlainSecureString -Plain $Value
    }

    switch ($Type) {
        'String'    { return $Value }
        'ByteArray' {
            # Unary comma prevents PowerShell from unrolling the byte[] return
            # value into a generic Object[] across the function boundary.
            return ,[System.Convert]::FromBase64String($Value)
        }
        'PSCredential' {
            $obj = $Value | ConvertFrom-Json
            $pw = ConvertTo-PlainSecureString -Plain ([string]$obj.Password)
            return [System.Management.Automation.PSCredential]::new([string]$obj.UserName, $pw)
        }
        'Hashtable' {
            $obj = $Value | ConvertFrom-Json
            $ht = @{}
            foreach ($prop in $obj.PSObject.Properties) {
                $entry = $prop.Value
                if ($entry -is [PSCustomObject] -and
                    $entry.PSObject.Properties[$script:SecureStringMarkerKey] -and
                    $entry.$($script:SecureStringMarkerKey)) {
                    # Sentinel-wrapped SecureString — rebuild it directly without
                    # descending further into the marker object.
                    $ht[$prop.Name] = ConvertTo-PlainSecureString -Plain ([string]$entry.v)
                }
                else {
                    # Recursively rebuild nested PSCustomObjects as Hashtables so
                    # the in/out shape is symmetric for arbitrary depth.
                    $ht[$prop.Name] = ConvertTo-HashtableTree -InputObject $entry
                }
            }
            return $ht
        }
        default {
            Write-Warning "Unknown $script:TypeTagKey value '$Type' on stored secret; returning raw value as SecureString."
            return ConvertTo-PlainSecureString -Plain $Value
        }
    }
}

function ConvertTo-PlainSecureString {
    <#
    .SYNOPSIS
        Wraps a plaintext string in a read-only SecureString.

    .OUTPUTS
        [System.Security.SecureString]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Plaintext originated from an authenticated Infisical fetch; wrapping it in a SecureString is the safest representation we can offer the caller.')]
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Plain
    )

    $ss = [System.Security.SecureString]::new()
    foreach ($c in $Plain.ToCharArray()) { $ss.AppendChar($c) }
    $ss.MakeReadOnly()
    return $ss
}

function ConvertTo-SecretManagementType {
    <#
    .SYNOPSIS
        Maps a stored type tag to a SecretManagement.SecretType enum value.

    .OUTPUTS
        [Microsoft.PowerShell.SecretManagement.SecretType]
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string] $Tag
    )

    # Resolve at runtime — see Get-SecretInfo for why we avoid parse-time literals.
    $SecretTypeEnum = 'Microsoft.PowerShell.SecretManagement.SecretType' -as [type]

    switch ($Tag) {
        'String'       { return $SecretTypeEnum::String }
        'PSCredential' { return $SecretTypeEnum::PSCredential }
        'Hashtable'    { return $SecretTypeEnum::Hashtable }
        'ByteArray'    { return $SecretTypeEnum::ByteArray }
        default        { return $SecretTypeEnum::SecureString }
    }
}

function Get-RelativeSecretName {
    <#
    .SYNOPSIS
        Builds the SecretManagement-visible name for a secret stored at a sub-path.

    .DESCRIPTION
        Given the vault's configured BasePath, the secret's absolute SecretPath,
        and its bare key, returns either '<key>' (when at the base) or
        '<relative>/<key>' (when nested below the base). This is the inverse of
        Resolve-InfisicalName for outbound naming.

    .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $BasePath,

        [Parameter(Mandatory)]
        [string] $SecretPath,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $base = $BasePath.TrimEnd('/')
    if ([string]::IsNullOrEmpty($base)) { $base = '' }

    $abs = $SecretPath.TrimEnd('/')
    if ([string]::IsNullOrEmpty($abs)) { $abs = '' }

    if ($abs -eq $base) {
        return $Name
    }

    $relative = $abs
    if (-not [string]::IsNullOrEmpty($base) -and $abs.StartsWith("$base/")) {
        $relative = $abs.Substring($base.Length + 1)
    }
    elseif ([string]::IsNullOrEmpty($base) -and $abs.StartsWith('/')) {
        $relative = $abs.Substring(1)
    }

    if ([string]::IsNullOrEmpty($relative)) {
        return $Name
    }
    return "$relative/$Name"
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
    $basePath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters
    $resolved = Resolve-InfisicalName -Name $Name -BasePath $basePath

    $secret = Get-InfisicalSecret -Name $resolved.Name -SecretPath $resolved.SecretPath -ErrorAction SilentlyContinue
    if ($null -eq $secret) {
        return $null
    }

    $typeTag = $null
    if ($null -ne $secret.Metadata -and $secret.Metadata.ContainsKey($script:TypeTagKey)) {
        $typeTag = [string]$secret.Metadata[$script:TypeTagKey]
    }

    # Fast path: legacy (untagged) and SecureString secrets bypass the
    # plaintext round-trip — InfisicalSecret.Value is already a SecureString.
    if ([string]::IsNullOrEmpty($typeTag) -or $typeTag -eq 'SecureString') {
        return $secret.Value
    }

    return ConvertFrom-InfisicalSecretPayload -Value $secret.GetValue() -Type $typeTag
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
    $basePath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters
    $resolved = Resolve-InfisicalName -Name $Name -BasePath $basePath
    Write-Verbose "Set-Secret: '$Name' resolved to key='$($resolved.Name)' path='$($resolved.SecretPath)' (base='$basePath')"

    # Serialise the typed -Secret to Infisical's single-string storage model and
    # capture the original SecretType for round-trip on read.
    $payload = ConvertTo-InfisicalSecretPayload -Secret $Secret
    $secureValue = ConvertTo-PlainSecureString -Plain $payload.Value

    # Check existence so we can choose create vs update and preserve any custom
    # metadata the user attached via the Infisical UI.
    $existing = Get-InfisicalSecret -Name $resolved.Name -SecretPath $resolved.SecretPath -ErrorAction SilentlyContinue

    $metadata = @{}
    if ($null -ne $existing -and $null -ne $existing.Metadata) {
        foreach ($k in $existing.Metadata.Keys) { $metadata[[string]$k] = $existing.Metadata[$k] }
    }
    $metadata[$script:TypeTagKey] = $payload.Type

    if ($null -ne $existing) {
        Set-InfisicalSecret -Name $resolved.Name -Value $secureValue -SecretPath $resolved.SecretPath -Metadata $metadata -Confirm:$false -ErrorAction Stop
    }
    else {
        # New secret at a sub-path: ensure the folder hierarchy exists first.
        if ($resolved.SecretPath -ne $basePath -and $resolved.SecretPath -ne '/') {
            Initialize-InfisicalFolderPath -TargetPath $resolved.SecretPath
        }
        New-InfisicalSecret -Name $resolved.Name -Value $secureValue -SecretPath $resolved.SecretPath -Metadata $metadata -Confirm:$false -ErrorAction Stop
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
    $basePath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters
    $resolved = Resolve-InfisicalName -Name $Name -BasePath $basePath

    Remove-InfisicalSecret -Name $resolved.Name -SecretPath $resolved.SecretPath -Confirm:$false -ErrorAction Stop

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
    $basePath = Resolve-SecretPath -AdditionalParameters $AdditionalParameters

    # Recurse so secrets nested under sub-paths are discoverable. Each result's
    # name is qualified with its relative path so it can round-trip through
    # Get/Set/Remove-Secret as 'subpath/key'.
    $secrets = Get-InfisicalSecrets -SecretPath $basePath -Recursive -ErrorAction Stop

    if ($null -eq $secrets) {
        return @()
    }

    # Resolve SecretManagement types at runtime rather than parse time.
    # When this module is loaded as a NestedModule of PSInfisical, SecretManagement
    # may not yet be imported, causing parse-time [type] literals to fail.
    $SecretInfoType = 'Microsoft.PowerShell.SecretManagement.SecretInformation' -as [type]

    $named = foreach ($s in $secrets) {
        $tag = $null
        if ($null -ne $s.Metadata -and $s.Metadata.ContainsKey($script:TypeTagKey)) {
            $tag = [string]$s.Metadata[$script:TypeTagKey]
        }
        [pscustomobject]@{
            Secret = $s
            Name   = Get-RelativeSecretName -BasePath $basePath -SecretPath $s.Path -Name $s.Name
            Type   = ConvertTo-SecretManagementType -Tag $tag
        }
    }

    if (-not [string]::IsNullOrEmpty($Filter)) {
        $named = @($named | Where-Object { $_.Name -like $Filter })
    }

    foreach ($entry in $named) {
        $SecretInfoType::new(
            $entry.Name,
            $entry.Type,
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
