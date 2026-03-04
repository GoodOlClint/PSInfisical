# New-InfisicalSecret

Creates a new secret in Infisical.

## Syntax

```powershell
# SecureString value (recommended)
New-InfisicalSecret [-Name] <string> [-Value] <SecureString>
    [-Environment <string>] [-SecretPath <string>] [-ProjectId <string>]
    [-Comment <string>] [-SkipMultilineEncoding] [-PassThru] [-WhatIf] [-Confirm]

# Plaintext value (with warning)
New-InfisicalSecret [-Name] <string> -PlainTextValue <string>
    [-Environment <string>] [-SecretPath <string>] [-ProjectId <string>]
    [-Comment <string>] [-SkipMultilineEncoding] [-PassThru] [-WhatIf] [-Confirm]
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| Name | string | Yes | The name (key) of the secret to create |
| Value | SecureString | Yes (SecureValue set) | Secret value as SecureString |
| PlainTextValue | string | Yes (PlainTextValue set) | Secret value as plain string (warns) |
| Environment | string | No | Environment slug, overrides session default |
| SecretPath | string | No | Infisical folder path. Default: `/` |
| ProjectId | string | No | Project/workspace ID, overrides session default |
| Comment | string | No | Optional note/comment for the secret |
| SkipMultilineEncoding | switch | No | Skip encoding for multiline values |
| PassThru | switch | No | Return the created InfisicalSecret object |

## Examples

### Example 1: Create a secret with SecureString

```powershell
$value = Read-Host -AsSecureString -Prompt 'Enter secret value'
New-InfisicalSecret -Name 'DATABASE_URL' -Value $value
```

Creates a new secret using a SecureString value (recommended approach).

### Example 2: Create with plaintext and get the result

```powershell
$created = New-InfisicalSecret 'API_KEY' -PlainTextValue 'sk-123' -PassThru
$created.Version  # 1
```

Creates a secret with a plaintext value (issues a warning) and returns the created object.

### Example 3: Create with a comment in a specific path

```powershell
$value = ConvertTo-SecureString 'mypassword' -AsPlainText -Force
New-InfisicalSecret -Name 'DB_PASSWORD' -Value $value `
    -SecretPath '/database' -Comment 'Production DB password'
```

Creates a secret in a specific path with a descriptive comment.

## Notes

- Use `SecureString` values whenever possible to minimize plaintext exposure.
- `-PlainTextValue` issues a `Write-Warning` every time it is used as a reminder.
- Supports `-WhatIf` to preview the operation without creating the secret.
- Throws an error if the secret already exists (API returns conflict).

## Related Commands

- [Set-InfisicalSecret](Set-InfisicalSecret.md)
- [Get-InfisicalSecret](Get-InfisicalSecret.md)
- [Remove-InfisicalSecret](Remove-InfisicalSecret.md)
