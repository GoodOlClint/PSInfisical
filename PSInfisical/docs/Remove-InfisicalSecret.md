# Remove-InfisicalSecret

Removes a secret from Infisical.

## Syntax

```powershell
Remove-InfisicalSecret [-Name] <string> [-Environment <string>]
    [-SecretPath <string>] [-ProjectId <string>] [-WhatIf] [-Confirm]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| Name | string | Yes | The name (key) of the secret to remove |
| Environment | string | No | Environment slug, overrides session default |
| SecretPath | string | No | Infisical folder path. Default: `/` |
| ProjectId | string | No | Project/workspace ID, overrides session default |

## Examples

### Example 1: Remove a single secret

```powershell
Remove-InfisicalSecret -Name 'OLD_API_KEY'
```

Removes a secret with confirmation prompt (ConfirmImpact is High).

### Example 2: Remove without confirmation

```powershell
Remove-InfisicalSecret -Name 'TEMP_TOKEN' -Confirm:$false
```

Removes a secret bypassing the confirmation prompt.

### Example 3: Bulk remove via pipeline

```powershell
Get-InfisicalSecrets -Filter { $_.Name -like 'TEMP_*' } | Remove-InfisicalSecret -Confirm:$false
```

Removes all secrets matching the filter using pipeline input.

## Notes

- This is a destructive operation. The secret and all its versions are permanently deleted.
- `ConfirmImpact` is set to `High`, so confirmation is prompted by default.
- Use `-WhatIf` to preview which secrets would be removed.
- Accepts pipeline input by property name (`Name`, `Environment`, `SecretPath`, `ProjectId`).
- Writes a non-terminating error if the secret is not found.

## Related Commands

- [Get-InfisicalSecrets](Get-InfisicalSecrets.md)
- [Get-InfisicalSecret](Get-InfisicalSecret.md)
- [New-InfisicalSecret](New-InfisicalSecret.md)
