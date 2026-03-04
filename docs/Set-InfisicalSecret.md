# Set-InfisicalSecret

Updates an existing secret in Infisical.

## Syntax

```powershell
# SecureString value (recommended)
Set-InfisicalSecret [-Name] <string> [-Value] <SecureString>
    [-Environment <string>] [-SecretPath <string>] [-ProjectId <string>]
    [-Comment <string>] [-PassThru] [-WhatIf] [-Confirm]

# Plaintext value (with warning)
Set-InfisicalSecret [-Name] <string> -PlainTextValue <string>
    [-Environment <string>] [-SecretPath <string>] [-ProjectId <string>]
    [-Comment <string>] [-PassThru] [-WhatIf] [-Confirm]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| Name | string | Yes | The name (key) of the secret to update |
| Value | SecureString | Yes (SecureValue set) | New secret value as SecureString |
| PlainTextValue | string | Yes (PlainTextValue set) | New secret value as plain string (warns) |
| Environment | string | No | Environment slug, overrides session default |
| SecretPath | string | No | Infisical folder path. Default: `/` |
| ProjectId | string | No | Project/workspace ID, overrides session default |
| Comment | string | No | Optional note/comment to set on the secret |
| PassThru | switch | No | Return the updated InfisicalSecret object |

## Examples

### Example 1: Update a secret value

```powershell
$newValue = Read-Host -AsSecureString -Prompt 'New value'
Set-InfisicalSecret -Name 'DATABASE_URL' -Value $newValue
```

Updates an existing secret with a new SecureString value.

### Example 2: Update and get the result

```powershell
$updated = Set-InfisicalSecret 'API_KEY' -PlainTextValue 'sk-new-key' -PassThru
$updated.Version  # incremented version number
```

Updates a secret and returns the updated object showing the new version.

### Example 3: Update with a comment

```powershell
$value = ConvertTo-SecureString 'rotated-password' -AsPlainText -Force
Set-InfisicalSecret -Name 'DB_PASSWORD' -Value $value -Comment 'Rotated on 2024-01-15'
```

Updates a secret value and its comment.

## Notes

- Creates a new version of the secret; previous versions remain accessible.
- Use `SecureString` values whenever possible to minimize plaintext exposure.
- Supports pipeline input via `ValueFromPipelineByPropertyName` for Name, Environment, SecretPath, and ProjectId.

## Related Commands

- [Get-InfisicalSecret](Get-InfisicalSecret.md)
- [New-InfisicalSecret](New-InfisicalSecret.md)
- [Get-InfisicalSecretVersion](Get-InfisicalSecretVersion.md)
