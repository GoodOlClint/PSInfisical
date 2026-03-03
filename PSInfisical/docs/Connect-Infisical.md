# Connect-Infisical

Connects to the Infisical secrets management API and establishes an authenticated session.

## Syntax

```powershell
# UniversalAuth (machine identity)
Connect-Infisical -ClientId <string> -ClientSecret <SecureString> -ProjectId <string>
    [-ApiUrl <string>] [-Environment <string>] [-PassThru]

# Static Token
Connect-Infisical -Token <SecureString> -ProjectId <string>
    [-ApiUrl <string>] [-Environment <string>] [-PassThru]

# Pre-obtained AccessToken
Connect-Infisical -AccessToken <SecureString> -ProjectId <string>
    [-ApiUrl <string>] [-Environment <string>] [-PassThru]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| ClientId | string | Yes (UniversalAuth) | Machine Identity Client ID |
| ClientSecret | SecureString | Yes (UniversalAuth) | Machine Identity Client Secret |
| Token | SecureString | Yes (Token) | Static API token |
| AccessToken | SecureString | Yes (AccessToken) | Pre-obtained JWT access token |
| ApiUrl | string | No | API base URL. Default: `https://app.infisical.com/api` |
| ProjectId | string | Yes | Infisical workspace/project ID |
| Environment | string | No | Default environment slug. Default: `prod` |
| PassThru | switch | No | Return the session object |

## Examples

### Example 1: Connect with UniversalAuth

```powershell
$secret = Read-Host -AsSecureString -Prompt 'Client Secret'
Connect-Infisical -ClientId 'client-id-here' -ClientSecret $secret -ProjectId 'proj-abc123'
```

Authenticates using a Machine Identity with Universal Auth credentials.

### Example 2: Connect with a static token

```powershell
$token = Read-Host -AsSecureString -Prompt 'API Token'
Connect-Infisical -Token $token -ProjectId 'proj-abc123'
```

Connects using a static API token for quick access.

### Example 3: Connect to a self-hosted instance

```powershell
$secret = Read-Host -AsSecureString -Prompt 'Client Secret'
Connect-Infisical -ClientId 'my-id' -ClientSecret $secret `
    -ProjectId 'proj-abc123' `
    -ApiUrl 'https://infisical.mycompany.com/api' `
    -Environment 'staging'
```

Connects to a self-hosted Infisical instance with a non-default environment.

## Notes

- The session is stored at module scope. Only one session can be active at a time.
- Calling `Connect-Infisical` again replaces the existing session.
- UniversalAuth credentials are stored in the session for automatic token refresh.
- Static tokens and pre-obtained access tokens cannot be auto-refreshed.

## Related Commands

- [Disconnect-Infisical](Disconnect-Infisical.md)
- [Get-InfisicalSecret](Get-InfisicalSecret.md)
- [Get-InfisicalSecrets](Get-InfisicalSecrets.md)
