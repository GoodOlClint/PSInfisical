# PSInfisical

A PowerShell module providing a clean, idiomatic interface to the [Infisical](https://infisical.com) secrets management API.

## Overview

PSInfisical enables you to manage secrets stored in Infisical directly from PowerShell. It covers secrets CRUD operations with full SecureString support, multiple authentication methods, and pipeline-friendly output.

**What PSInfisical covers:**
- Authentication (Universal Auth, static tokens, pre-obtained JWTs)
- Create, read, update, and delete secrets
- List secrets with filtering and hashtable output
- Secret version history
- SecureString-first design for secret values

**What PSInfisical does not cover (planned for separate modules):**
- Certificates and PKI
- SSH key management
- Dynamic secrets
- Secret rotation configuration

## Installation

### From PSGallery (coming soon)

```powershell
Install-Module -Name PSInfisical -Scope CurrentUser
```

### Manual Install from Repository

```powershell
git clone https://github.com/PLACEHOLDER/PSInfisical.git
Import-Module ./PSInfisical/PSInfisical/PSInfisical.psd1
```

## Quick Start

```powershell
Import-Module PSInfisical

# Connect with Universal Auth
$clientSecret = Read-Host -AsSecureString -Prompt 'Client Secret'
Connect-Infisical -ClientId 'your-client-id' -ClientSecret $clientSecret -ProjectId 'your-project-id'

# Get all secrets
Get-InfisicalSecrets

# Get a specific secret
$dbUrl = Get-InfisicalSecret 'DATABASE_URL' -Raw
```

## Authentication

PSInfisical supports three authentication methods:

### Universal Auth (Machine Identity) — Recommended

```powershell
$secret = Read-Host -AsSecureString -Prompt 'Client Secret'
Connect-Infisical -ClientId 'your-client-id' -ClientSecret $secret -ProjectId 'proj-123'
```

Universal Auth tokens are automatically refreshed when they approach expiry.

### Static Token

```powershell
$token = Read-Host -AsSecureString -Prompt 'API Token'
Connect-Infisical -Token $token -ProjectId 'proj-123'
```

Static tokens cannot be auto-refreshed. You will receive a warning when the session expires.

### Pre-obtained Access Token

```powershell
$jwt = ConvertTo-SecureString $env:INFISICAL_TOKEN -AsPlainText -Force
Connect-Infisical -AccessToken $jwt -ProjectId 'proj-123'
```

Useful in CI/CD pipelines where a token is already available.

## Self-Hosted Infisical

Use the `-ApiUrl` parameter to point to your self-hosted instance:

```powershell
Connect-Infisical -ClientId 'id' -ClientSecret $secret `
    -ProjectId 'proj-123' `
    -ApiUrl 'https://infisical.mycompany.com/api'
```

## Common Patterns

### Inject secrets as environment variables

```powershell
$secrets = Get-InfisicalSecrets -AsHashtable
$secrets.GetEnumerator() | ForEach-Object {
    [System.Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'Process')
}

# Now use secrets as env vars
& my-app.exe
```

### Bulk copy secrets between environments

```powershell
Get-InfisicalSecrets -Environment 'staging' | ForEach-Object {
    $value = $_.Value  # Already a SecureString
    New-InfisicalSecret -Name $_.Name -Value $value -Environment 'prod' -ErrorAction SilentlyContinue
}
```

### Use in CI/CD pipeline

```powershell
# In your pipeline script
$token = ConvertTo-SecureString $env:INFISICAL_TOKEN -AsPlainText -Force
Connect-Infisical -AccessToken $token -ProjectId $env:INFISICAL_PROJECT_ID

$dbUrl = Get-InfisicalSecret 'DATABASE_URL' -Raw
$env:DATABASE_URL = $dbUrl
```

### Pipe to Remove for cleanup

```powershell
Get-InfisicalSecrets -Filter { $_.Name -like 'TEMP_*' } | Remove-InfisicalSecret -Confirm:$false
```

## SecretManagement Integration

PSInfisical includes a [Microsoft.PowerShell.SecretManagement](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/overview) vault extension. This lets you use standard `Get-Secret` / `Set-Secret` commands to access Infisical secrets alongside other vault providers.

### Prerequisites

```powershell
Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
```

### Register the Vault

```powershell
Register-SecretVault -Name 'Infisical' -ModuleName 'PSInfisical' -VaultParameters @{
    ApiUrl       = 'https://app.infisical.com'   # Optional, defaults to cloud
    ClientId     = 'your-client-id'               # UniversalAuth
    ClientSecret = 'your-client-secret'           # UniversalAuth
    ProjectId    = 'your-project-id'              # Required
    Environment  = 'prod'                         # Optional, defaults to 'prod'
    SecretPath   = '/'                            # Optional, defaults to '/'
}
```

All three authentication methods are supported via `VaultParameters`:
- **UniversalAuth**: `ClientId` + `ClientSecret`
- **Static Token**: `Token`
- **Pre-obtained JWT**: `AccessToken`

### Usage

```powershell
# Verify vault connectivity
Test-SecretVault -Name 'Infisical'

# Get a secret (returns SecureString)
$secret = Get-Secret -Name 'DATABASE_URL' -Vault 'Infisical'

# Get a secret as plaintext
$plaintext = Get-Secret -Name 'DATABASE_URL' -Vault 'Infisical' -AsPlainText

# Create or update a secret
Set-Secret -Name 'NEW_KEY' -Secret 'my-value' -Vault 'Infisical'

# List all secrets
Get-SecretInfo -Vault 'Infisical'

# List secrets matching a pattern
Get-SecretInfo -Filter 'DB_*' -Vault 'Infisical'

# Remove a secret
Remove-Secret -Name 'OLD_KEY' -Vault 'Infisical'
```

## SecureString Guidance

PSInfisical stores all secret values as `SecureString` by default. This prevents accidental exposure in logs, transcripts, and debug output.

**Accessing plaintext values:**

```powershell
# Method 1: GetValue() on the secret object
$secret = Get-InfisicalSecret 'MY_SECRET'
$plaintext = $secret.GetValue()

# Method 2: -Raw switch returns plaintext directly
$plaintext = Get-InfisicalSecret 'MY_SECRET' -Raw

# Method 3: .NET conversion
$plaintext = [System.Net.NetworkCredential]::new('', $secret.Value).Password
```

**When is `-Raw` appropriate?**
- Script interpolation where you need the string value immediately
- Setting environment variables
- Passing to external tools that require plaintext

**When to use SecureString (default):**
- Storing references for later use
- Passing between functions
- Any scenario where the value might be logged

## Error Handling

| Error | When | Terminating? |
|-------|------|-------------|
| `InfisicalNotConnected` | No active session | Yes |
| `InfisicalSessionExpired` | Token expired, can't refresh | Yes |
| `InfisicalAuthenticationFailed` | 401 from API | Yes |
| `InfisicalAccessDenied` | 403 from API | Yes |
| `InfisicalSecretNotFound` | Secret doesn't exist | No |
| `InfisicalServerError` | 5xx from API | Yes |
| `InfisicalRateLimitExceeded` | 429 after 3 retries | Yes |

Non-terminating errors allow pipeline continuation. Use `-ErrorAction Stop` to make them terminating.

## Contributing

### Prerequisites

```powershell
Install-Module -Name InvokeBuild -Scope CurrentUser
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

### Running Tests

```powershell
# Run unit tests
Invoke-Pester -Path ./PSInfisical/Tests/Unit/ -Output Detailed

# Run all tests via build script
Invoke-Build Test
```

### Build

```powershell
# Full build: Clean → Build → Test → Analyze
Invoke-Build

# Individual tasks
Invoke-Build Clean
Invoke-Build Build
Invoke-Build Test
Invoke-Build Analyze
Invoke-Build Package
```

### Code Standards

- PowerShell 7.2+ target with 5.1 compatibility
- OTBS brace style, 4-space indentation
- PascalCase parameters, camelCase local variables
- All functions must have comment-based help
- All functions must pass PSScriptAnalyzer

## License

MIT License - see [LICENSE](LICENSE) for details.
