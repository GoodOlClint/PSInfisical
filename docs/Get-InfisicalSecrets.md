# Get-InfisicalSecrets

Retrieves all secrets from an Infisical path.

## Syntax

```powershell
Get-InfisicalSecrets [-Environment <string>] [-SecretPath <string>]
    [-ProjectId <string>] [-Recursive] [-Filter <scriptblock>] [-AsHashtable]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| Environment | string | No | Environment slug, overrides session default |
| SecretPath | string | No | Infisical folder path. Default: `/` |
| ProjectId | string | No | Project/workspace ID, overrides session default |
| Recursive | switch | No | Include secrets from sub-paths |
| Filter | scriptblock | No | Client-side filter scriptblock |
| AsHashtable | switch | No | Return a hashtable of Name=Value pairs |

## Examples

### Example 1: Get all secrets in default path

```powershell
Get-InfisicalSecrets
```

Returns all secrets in the default environment and root path.

### Example 2: Get secrets as a hashtable for environment variable injection

```powershell
$secrets = Get-InfisicalSecrets -AsHashtable
$secrets.GetEnumerator() | ForEach-Object {
    [System.Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'Process')
}
```

Retrieves all secrets as a hashtable and injects them as environment variables.

### Example 3: Filter secrets client-side

```powershell
Get-InfisicalSecrets -Filter { $_.Name -like 'DB_*' }
```

Returns only secrets whose names start with `DB_`.

## Notes

- Each secret is emitted individually to the pipeline for streaming processing.
- The `-Filter` parameter runs client-side after all secrets are retrieved from the API.
- `-AsHashtable` returns plaintext string values in the hashtable, not SecureStrings.
- Use `-Recursive` to include secrets from all sub-paths (up to Infisical's depth limit).

## Related Commands

- [Get-InfisicalSecret](Get-InfisicalSecret.md)
- [Remove-InfisicalSecret](Remove-InfisicalSecret.md)
