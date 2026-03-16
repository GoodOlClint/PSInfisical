# PSInfisical

[![CI](https://github.com/GoodOlClint/PSInfisical/actions/workflows/ci.yml/badge.svg)](https://github.com/GoodOlClint/PSInfisical/actions/workflows/ci.yml)
[![PSGallery](https://img.shields.io/powershellgallery/v/PSInfisical?label=PSGallery)](https://www.powershellgallery.com/packages/PSInfisical)

A PowerShell module providing a clean, idiomatic interface to the [Infisical](https://infisical.com) secrets management API, with built-in [Microsoft.PowerShell.SecretManagement](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/overview) vault extension support.

## Overview

PSInfisical enables you to manage secrets stored in Infisical directly from PowerShell. It covers the full Infisical Secrets Vault API with SecureString support, 10 authentication methods, pipeline-friendly output, and integration with the standard SecretManagement framework.

**What PSInfisical covers:**
- Authentication (Universal Auth, AWS, Azure, GCP, Kubernetes, OIDC, JWT, LDAP, static tokens, pre-obtained JWTs)
- Secrets: create, read, update, delete, version history, bulk operations
- Folders: create, list, rename, delete
- Tags: create, list, update, delete, attach to secrets
- Secret imports: create, list, update, delete (cross-environment secret sharing)
- Project and environment discovery
- Server API version detection for self-hosted compatibility
- SecureString-first design for secret values
- Microsoft.PowerShell.SecretManagement vault extension

**What PSInfisical does not cover (separate Infisical products):**
- Certificates and PKI
- SSH key management
- Dynamic secrets
- KMS encryption/signing

## Installation

### From PSGallery

```powershell
Install-Module -Name PSInfisical -Scope CurrentUser
```

### Manual Install from Repository

```powershell
git clone https://github.com/GoodOlClint/PSInfisical.git
Import-Module ./PSInfisical/PSInfisical.psd1
```

## Quick Start

```powershell
Import-Module PSInfisical

# Connect with Universal Auth (machine identity)
$clientSecret = Read-Host -AsSecureString -Prompt 'Client Secret'
Connect-Infisical -ClientId 'your-client-id' -ClientSecret $clientSecret -ProjectId 'your-project-id'

# Get all secrets
Get-InfisicalSecrets

# Get a specific secret as plaintext
$dbUrl = Get-InfisicalSecret 'DATABASE_URL' -Raw
```

## Prerequisites: Setting Up Infisical Authentication

Before using PSInfisical, you need credentials from your Infisical instance. The recommended approach is **Universal Auth** with a Machine Identity.

### Creating a Machine Identity (Universal Auth)

Machine Identities are non-human accounts used for programmatic access. To create one:

1. **In the Infisical dashboard**, navigate to **Organization Settings > Machine Identities**
2. Click **Create Identity** and give it a descriptive name (e.g. `powershell-ci`, `deploy-agent`)
3. Under the identity's **Authentication** tab, click **Add Auth Method** and select **Universal Auth**
4. Note the **Client ID** displayed on the identity page
5. Click **Create Client Secret** to generate a Client Secret — copy it immediately as it is only shown once
6. Navigate to your **Project Settings > Access Control**, click **Add Member**, and add the Machine Identity
7. Assign the appropriate **role** (e.g. `Developer` for read/write, `Viewer` for read-only)

You now have the three values needed to connect:
- **Client ID** — the identity's unique identifier
- **Client Secret** — the generated secret (store securely)
- **Project ID** — found in your project's URL or settings page

### Alternative Authentication Methods

| Method | Use Case | Auto-Refresh |
|--------|----------|:------------:|
| **Universal Auth** (`-ClientId` + `-ClientSecret`) | Production, CI/CD, automation | Yes |
| **AWS Auth** (`-AWSIdentityDocument`) | EC2 instances, Lambda | No |
| **Azure Auth** (`-AzureJwt`) | Azure managed identities | No |
| **GCP Auth** (`-GCPIdentityToken`) | GCP workloads | No |
| **Kubernetes Auth** (`-KubernetesServiceAccountToken` + `-KubernetesIdentityId`) | K8s pods | No |
| **OIDC Auth** (`-OIDCToken` + `-OIDCIdentityId`) | OIDC providers (GitHub Actions, etc.) | No |
| **JWT Auth** (`-Jwt` + `-JwtIdentityId`) | Generic JWT authentication | No |
| **LDAP Auth** (`-LDAPUsername` + `-LDAPPassword`) | LDAP/Active Directory | No |
| **Static Token** (`-Token`) | Quick testing, service accounts | No |
| **Pre-obtained JWT** (`-AccessToken`) | CI systems that provide tokens externally | No |

## Authentication

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

## Command Reference

### Session Management

| Command | Description |
|---------|-------------|
| `Connect-Infisical` | Authenticate and establish a session |
| `Disconnect-Infisical` | Clear the current session |

### Secret Operations

| Command | Description |
|---------|-------------|
| `Get-InfisicalSecret` | Get a single secret by name (`-Raw` for plaintext) |
| `Get-InfisicalSecrets` | List all secrets (`-Filter`, `-Recursive`, `-AsHashtable`, `-TagSlugs`, `-MetadataFilter`) |
| `New-InfisicalSecret` | Create a new secret (`-TagIds`, `-Metadata`, `-Type`, `-Force` for upsert) |
| `Set-InfisicalSecret` | Update an existing secret (`-NewName` to rename, `-TagIds`, `-Metadata`) |
| `Remove-InfisicalSecret` | Delete a secret (supports pipeline input, `-Type`) |
| `Get-InfisicalSecretVersion` | View secret version history (`-Limit`) |

### Bulk Operations

| Command | Description |
|---------|-------------|
| `New-InfisicalSecretBulk` | Create multiple secrets in a single API call |
| `Set-InfisicalSecretBulk` | Update multiple secrets in a single API call |
| `Remove-InfisicalSecretBulk` | Delete multiple secrets in a single API call (supports pipeline) |

### Folder Management

| Command | Description |
|---------|-------------|
| `Get-InfisicalFolder` | List folders or get by ID (`-Recursive`) |
| `New-InfisicalFolder` | Create a folder (`-Description`) |
| `Set-InfisicalFolder` | Rename a folder or update description |
| `Remove-InfisicalFolder` | Delete a folder (`-ForceDelete` for non-empty folders) |

### Tag Management

| Command | Description |
|---------|-------------|
| `Get-InfisicalTag` | List tags, get by ID or slug |
| `New-InfisicalTag` | Create a tag with slug and color |
| `Set-InfisicalTag` | Update tag slug or color |
| `Remove-InfisicalTag` | Delete a tag |

### Secret Imports

| Command | Description |
|---------|-------------|
| `Get-InfisicalSecretImport` | List secret imports at a path |
| `New-InfisicalSecretImport` | Import secrets from another environment/path (`-IsReplication`) |
| `Set-InfisicalSecretImport` | Update import source or position |
| `Remove-InfisicalSecretImport` | Delete a secret import |

### Discovery

| Command | Description |
|---------|-------------|
| `Get-InfisicalEnvironment` | List environments in a project |
| `Get-InfisicalProject` | List projects or get by ID |

### Common Parameters

Most commands accept these optional parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Environment` | Environment slug (`dev`, `staging`, `prod`) | Session default (`prod`) |
| `-SecretPath` | Infisical folder path | `/` |
| `-ProjectId` | Override the session's project ID | Session default |

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

### Set default parameters for your session

Use `$PSDefaultParameterValues` to avoid repeating the same `-Environment` or `-SecretPath` on every call:

```powershell
$PSDefaultParameterValues['*-Infisical*:Environment'] = 'staging'
$PSDefaultParameterValues['*-Infisical*:SecretPath']   = '/backend'
```

### Idempotent secret creation in CI/CD

Use `-Force` with `New-InfisicalSecret` to create or update a secret in a single call:

```powershell
New-InfisicalSecret -Name 'DEPLOY_KEY' -Value $secureValue -Force
```

## SecretManagement Integration

PSInfisical includes a [Microsoft.PowerShell.SecretManagement](https://learn.microsoft.com/en-us/powershell/utility-modules/secretmanagement/overview) vault extension. This lets you use the standard `Get-Secret` / `Set-Secret` / `Remove-Secret` cmdlets to access Infisical secrets alongside other vault providers (Azure Key Vault, AWS Secrets Manager, KeePass, etc.).

### Why Use SecretManagement?

- **Unified interface** — one set of commands for all your secret stores
- **Interoperability** — scripts that use `Get-Secret` work with any vault provider
- **Default vault** — set Infisical as your default vault and skip `-Vault` on every call
- **Session caching** — the extension caches authenticated sessions per vault, so repeated calls don't re-authenticate

### Prerequisites

Install the SecretManagement module:

```powershell
Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
```

You also need a Machine Identity (or other auth credentials) — see [Prerequisites: Setting Up Infisical Authentication](#prerequisites-setting-up-infisical-authentication) above.

### Register the Vault

```powershell
Register-SecretVault -Name 'Infisical' -ModuleName 'PSInfisical' -VaultParameters @{
    ApiUrl       = 'https://app.infisical.com'   # Optional — defaults to Infisical Cloud
    ClientId     = 'your-client-id'               # Machine Identity Client ID
    ClientSecret = 'your-client-secret'           # Machine Identity Client Secret
    ProjectId    = 'your-project-id'              # Required — Infisical project ID
    Environment  = 'prod'                         # Optional — defaults to 'prod'
    SecretPath   = '/'                            # Optional — defaults to '/'
}
```

All authentication methods are supported via `VaultParameters`:

| VaultParameters Keys | Auth Method |
|----------------------|-------------|
| `ClientId` + `ClientSecret` | Universal Auth (recommended) |
| `AWSIdentityDocument` | AWS Auth |
| `AzureJwt` | Azure Auth |
| `GCPIdentityToken` | GCP Auth |
| `KubernetesServiceAccountToken` + `KubernetesIdentityId` | Kubernetes Auth |
| `OIDCToken` + `OIDCIdentityId` | OIDC Auth |
| `Jwt` + `JwtIdentityId` | JWT Auth |
| `LDAPUsername` + `LDAPPassword` | LDAP Auth |
| `Token` | Static API token |
| `AccessToken` | Pre-obtained JWT |

> **Note:** `VaultParameters` accepts both plain strings and `SecureString` values for credentials. Plain strings are automatically converted to `SecureString` internally.

### Verify Connectivity

After registering, verify that the vault can authenticate and access your project:

```powershell
Test-SecretVault -Name 'Infisical'
# Returns $true if authentication and API access succeed
```

### Usage

```powershell
# Get a secret (returns SecureString)
$secret = Get-Secret -Name 'DATABASE_URL' -Vault 'Infisical'

# Get a secret as plaintext
$plaintext = Get-Secret -Name 'DATABASE_URL' -Vault 'Infisical' -AsPlainText

# Create or update a secret
Set-Secret -Name 'NEW_KEY' -Secret 'my-value' -Vault 'Infisical'

# List all secrets
Get-SecretInfo -Vault 'Infisical'

# List secrets matching a wildcard pattern
Get-SecretInfo -Name 'DB_*' -Vault 'Infisical'

# Remove a secret
Remove-Secret -Name 'OLD_KEY' -Vault 'Infisical'
```

### Setting a Default Vault

To avoid specifying `-Vault 'Infisical'` on every call:

```powershell
Set-SecretVaultDefault -Name 'Infisical'

# Now these work without -Vault
Get-Secret -Name 'DATABASE_URL' -AsPlainText
Set-Secret -Name 'API_KEY' -Secret 'new-value'
```

### Multiple Vaults (Multi-Project / Multi-Environment)

You can register multiple vaults pointing to different Infisical projects or environments:

```powershell
Register-SecretVault -Name 'Infisical-Prod' -ModuleName 'PSInfisical' -VaultParameters @{
    ClientId     = $clientId
    ClientSecret = $clientSecret
    ProjectId    = 'proj-prod-123'
    Environment  = 'prod'
}

Register-SecretVault -Name 'Infisical-Dev' -ModuleName 'PSInfisical' -VaultParameters @{
    ClientId     = $clientId
    ClientSecret = $clientSecret
    ProjectId    = 'proj-dev-456'
    Environment  = 'dev'
}

# Access secrets from each vault independently
$prodDb = Get-Secret -Name 'DATABASE_URL' -Vault 'Infisical-Prod' -AsPlainText
$devDb  = Get-Secret -Name 'DATABASE_URL' -Vault 'Infisical-Dev' -AsPlainText
```

Each vault maintains its own authenticated session, so switching between vaults does not require re-authentication.

### Unregister a Vault

```powershell
Unregister-SecretVault -Name 'Infisical'
```

### SecretManagement Behavior Notes

- **All secrets are `SecureString`** — `Get-SecretInfo` reports every secret as `SecretType.SecureString`. Use `-AsPlainText` with `Get-Secret` to get the plaintext value.
- **`Set-Secret` is an upsert** — it creates the secret if it doesn't exist or updates it if it does.
- **`Remove-Secret` throws on missing secrets** — unlike `Get-Secret` which returns `$null`, removing a non-existent secret will throw an error.
- **Session caching** — the extension caches authenticated sessions per vault name. Sessions are automatically refreshed when they expire (Universal Auth only).
- **Folder scoping** — the `SecretPath` vault parameter scopes all operations to a specific Infisical folder. To access secrets in different folders, register separate vaults with different `SecretPath` values.

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
|-------|------|:------------:|
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
Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser
```

### Running Tests

```powershell
# Run unit tests
Invoke-Build Test

# Run integration tests (requires Docker)
Invoke-Build Test-Integration

# Run full pipeline: Clean -> Build -> Test -> Analyze
Invoke-Build
```

### Build

```powershell
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
