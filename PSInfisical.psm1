# PSInfisical.psm1
# Root module loader for PSInfisical. Dot-sources all class, private, and public
# function files in the correct order. Manages module-scoped session state.
# Dependencies: All .ps1 files in Classes/, Private/, and Public/ directories.

#Requires -Version 5.1

Set-StrictMode -Version Latest

# Ensure TLS 1.2 is available. PowerShell 5.1 on older Windows may default to
# TLS 1.0/1.1, which Infisical's API (and most modern services) will reject.
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# Module-scoped session variable — stores the current InfisicalSession.
# Accessed via $script:InfisicalSession from within module functions.
$script:InfisicalSession = $null

# Determine module root
$moduleRoot = $PSScriptRoot

# --- Class definitions (inline) ---
# Classes MUST be defined directly in the RootModule (not dot-sourced from
# separate files) so that 'using module PSInfisical' exports the types to
# the caller's scope. Dot-sourced classes only exist inside the module scope
# and are invisible to 'using module'. ScriptsToProcess would also work but
# breaks SecretManagement's Register-SecretVault internal module loading.

class InfisicalSession {
    [string] $ApiUrl
    [string] $ProjectId
    [string] $DefaultEnvironment
    [System.Security.SecureString] $AccessToken
    [Nullable[datetime]] $TokenExpiry
    [string] $AuthMethod          # UniversalAuth, Token, AccessToken
    [string] $ClientId            # Stored for re-auth (UniversalAuth only)
    [System.Security.SecureString] $ClientSecret  # Stored for re-auth (UniversalAuth only)

    [bool] $Connected
    [hashtable] $ApiCapabilities     # Tracks which API versions are available

    InfisicalSession() {
        $this.DefaultEnvironment = 'prod'
        $this.Connected = $false
        $this.ApiCapabilities = @{}
    }

    # Update Connected based on token state
    [void] UpdateConnectionStatus() {
        if ($null -eq $this.AccessToken) {
            $this.Connected = $false
            return
        }
        if ($null -ne $this.TokenExpiry -and $this.TokenExpiry -le [datetime]::UtcNow) {
            $this.Connected = $false
            return
        }
        $this.Connected = $true
    }

    [bool] IsTokenExpiringSoon() {
        if ($null -eq $this.TokenExpiry) {
            return $false
        }
        return ($this.TokenExpiry -le [datetime]::UtcNow.AddSeconds(60))
    }

    [bool] CanReauthenticate() {
        return ($this.AuthMethod -eq 'UniversalAuth' -and
                -not [string]::IsNullOrEmpty($this.ClientId) -and
                $null -ne $this.ClientSecret)
    }

    [string] GetAccessTokenPlainText() {
        if ($null -eq $this.AccessToken) {
            return $null
        }
        return [System.Net.NetworkCredential]::new('', $this.AccessToken).Password
    }

    [string] ToString() {
        $this.UpdateConnectionStatus()
        return "InfisicalSession: ApiUrl=$($this.ApiUrl), ProjectId=$($this.ProjectId), AuthMethod=$($this.AuthMethod), Connected=$($this.Connected)"
    }
}

class InfisicalSecret {
    [string] $Name
    [System.Security.SecureString] $Value
    [string] $Environment
    [string] $Path
    [string] $ProjectId
    [int] $Version
    [string] $Comment
    [datetime] $CreatedAt
    [datetime] $UpdatedAt
    [string] $Id
    [string[]] $TagIds
    [hashtable] $Metadata
    [int] $ReminderRepeatDays
    [string] $ReminderNote
    [string] $Type              # 'shared' or 'personal'

    InfisicalSecret() {
        $this.TagIds = @()
        $this.Metadata = @{}
        $this.Type = 'shared'
    }

    # Decrypts and returns the plaintext value. Use with care — the plaintext
    # string will remain in managed memory until garbage collected.
    [string] GetValue() {
        if ($null -eq $this.Value) {
            return $null
        }
        return [System.Net.NetworkCredential]::new('', $this.Value).Password
    }

    # Safe display that never leaks the secret value.
    [string] ToString() {
        return "$($this.Name)=<value hidden>"
    }
}

class InfisicalFolder {
    [string] $Id
    [string] $Name
    [string] $Environment
    [string] $Path              # Parent path (e.g., "/" means folder is at root)
    [string] $ProjectId
    [string] $Description
    [datetime] $CreatedAt
    [datetime] $UpdatedAt

    InfisicalFolder() { }

    [string] GetFullPath() {
        $parentPath = $this.Path.TrimEnd('/')
        return "$parentPath/$($this.Name)"
    }

    [string] ToString() {
        return "InfisicalFolder: $($this.GetFullPath()) (Environment=$($this.Environment))"
    }
}

class InfisicalTag {
    [string] $Id
    [string] $Name
    [string] $Slug
    [string] $Color
    [string] $ProjectId
    [datetime] $CreatedAt
    [datetime] $UpdatedAt

    InfisicalTag() { }

    [string] ToString() {
        return "InfisicalTag: $($this.Slug) ($($this.Color))"
    }
}

class InfisicalSecretImport {
    [string] $Id
    [string] $SourceEnvironment
    [string] $SourcePath
    [string] $Environment          # Destination environment
    [string] $Path                 # Destination path
    [string] $ProjectId
    [bool] $IsReplication
    [int] $Position
    [datetime] $CreatedAt
    [datetime] $UpdatedAt

    InfisicalSecretImport() { }

    [string] ToString() {
        $repl = if ($this.IsReplication) { ' [replication]' } else { '' }
        return "InfisicalSecretImport: $($this.SourceEnvironment):$($this.SourcePath) -> $($this.Environment):$($this.Path)$repl"
    }
}

class InfisicalIdentity {
    [string] $Id
    [string] $Name
    [string] $OrganizationId
    [string] $Role
    [string[]] $AuthMethods
    [bool] $HasDeleteProtection
    [hashtable] $Metadata
    [datetime] $CreatedAt
    [datetime] $UpdatedAt

    InfisicalIdentity() {
        $this.AuthMethods = @()
        $this.Metadata = @{}
    }

    [string] ToString() {
        return "InfisicalIdentity: $($this.Name) (Role=$($this.Role))"
    }
}

# --- Register type accelerators ---
# PowerShell classes defined in a module are NOT visible as type literals
# (e.g. [InfisicalSession]) when dot-sourcing function files within the same
# module. Type accelerators make the types globally resolvable at parse time,
# which is required for [OutputType()], parameter types, and ::new() calls
# in dot-sourced function files.
$script:TypeAcceleratorsType = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
@(
    @{ Name = 'InfisicalSession'; Type = [InfisicalSession] }
    @{ Name = 'InfisicalSecret';  Type = [InfisicalSecret] }
    @{ Name = 'InfisicalFolder';  Type = [InfisicalFolder] }
    @{ Name = 'InfisicalTag';     Type = [InfisicalTag] }
    @{ Name = 'InfisicalSecretImport'; Type = [InfisicalSecretImport] }
    @{ Name = 'InfisicalIdentity';     Type = [InfisicalIdentity] }
) | ForEach-Object {
    if (-not $script:TypeAcceleratorsType::Get.ContainsKey($_.Name)) {
        $script:TypeAcceleratorsType::Add($_.Name, $_.Type)
    }
}

# Clean up type accelerators when the module is removed to avoid leaking
# into the session after Remove-Module.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    @('InfisicalSession', 'InfisicalSecret', 'InfisicalFolder', 'InfisicalTag', 'InfisicalSecretImport', 'InfisicalIdentity') | ForEach-Object {
        if ($script:TypeAcceleratorsType::Get.ContainsKey($_)) {
            $script:TypeAcceleratorsType::Remove($_)
        }
    }
}

# --- Dot-source Private functions ---
$privatePath = Join-Path -Path $moduleRoot -ChildPath 'Private'
if (Test-Path -Path $privatePath) {
    $privateFiles = Get-ChildItem -Path $privatePath -Filter '*.ps1' -File
    foreach ($file in $privateFiles) {
        . $file.FullName
    }
}

# --- Dot-source Public functions ---
$publicPath = Join-Path -Path $moduleRoot -ChildPath 'Public'
if (Test-Path -Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -File
    foreach ($file in $publicFiles) {
        . $file.FullName
    }
}

# Note: FunctionsToExport in the manifest controls which functions are exported.
# Private functions are NOT listed there and therefore not accessible to module consumers.
