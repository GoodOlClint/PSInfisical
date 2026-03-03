# Get-InfisicalSecretVersion

Lists version history for a secret in Infisical.

## Syntax

```powershell
Get-InfisicalSecretVersion [-Name] <string> [-Environment <string>]
    [-SecretPath <string>] [-ProjectId <string>] [-Limit <int>]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| Name | string | Yes | The name (key) of the secret |
| Environment | string | No | Environment slug, overrides session default |
| SecretPath | string | No | Infisical folder path. Default: `/` |
| ProjectId | string | No | Project/workspace ID, overrides session default |
| Limit | int | No | Max versions to return. Default: 10, Max: 100 |

## Examples

### Example 1: Get recent versions

```powershell
Get-InfisicalSecretVersion -Name 'DATABASE_URL'
```

Returns up to 10 most recent versions of the secret.

### Example 2: Get last 5 versions

```powershell
Get-InfisicalSecretVersion 'API_KEY' -Limit 5
```

Returns the last 5 versions.

### Example 3: Compare current and previous values

```powershell
$versions = Get-InfisicalSecretVersion -Name 'DB_PASSWORD' -Limit 2
$current = [System.Net.NetworkCredential]::new('', $versions[0].Value).Password
$previous = [System.Net.NetworkCredential]::new('', $versions[1].Value).Password
$current -eq $previous  # Check if value changed
```

Retrieves two versions and compares their values.

## Notes

- Version values are returned as `SecureString` for security consistency.
- Use `[System.Net.NetworkCredential]::new('', $version.Value).Password` to access plaintext.
- Each version is fetched individually from the API, so large limits may be slow.
- Writes a non-terminating error if the secret is not found.

## Related Commands

- [Get-InfisicalSecret](Get-InfisicalSecret.md)
- [Set-InfisicalSecret](Set-InfisicalSecret.md)
