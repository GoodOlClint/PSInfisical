# Get-InfisicalSecret

Retrieves a single secret by name from Infisical.

## Syntax

```powershell
Get-InfisicalSecret [-Name] <string> [-Environment <string>] [-SecretPath <string>]
    [-ProjectId <string>] [-IncludeVersion] [-Raw]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| Name | string | Yes | The name (key) of the secret to retrieve |
| Environment | string | No | Environment slug, overrides session default |
| SecretPath | string | No | Infisical folder path. Default: `/` |
| ProjectId | string | No | Project/workspace ID, overrides session default |
| IncludeVersion | switch | No | Include version metadata in output |
| Raw | switch | No | Return just the plaintext string value |

## Examples

### Example 1: Get a secret as an object

```powershell
$secret = Get-InfisicalSecret -Name 'DATABASE_URL'
$secret.GetValue()  # Returns plaintext value
```

Retrieves the DATABASE_URL secret as an `InfisicalSecret` object with SecureString value.

### Example 2: Get a secret's plaintext value directly

```powershell
$connectionString = Get-InfisicalSecret 'DATABASE_URL' -Raw
```

Returns the secret value as a plain string for direct use in scripts.

### Example 3: Get a secret from a specific environment and path

```powershell
Get-InfisicalSecret -Name 'API_KEY' -Environment 'staging' -SecretPath '/services/api'
```

Retrieves a secret from a specific environment and folder path.

## Notes

- Secret values are returned as `SecureString` by default for security.
- Use the `GetValue()` method on the returned object to access the plaintext value.
- The `-Raw` switch is an explicit opt-in to receive plaintext directly.
- Writes a non-terminating error if the secret is not found, allowing pipeline continuation.
- Plaintext strings from `-Raw` or `GetValue()` remain in managed memory until garbage collected.

## Related Commands

- [Get-InfisicalSecrets](Get-InfisicalSecrets.md)
- [New-InfisicalSecret](New-InfisicalSecret.md)
- [Set-InfisicalSecret](Set-InfisicalSecret.md)
